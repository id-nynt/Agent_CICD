import jason.asSyntax.Literal;
import jason.asSyntax.Structure;
import jason.asSyntax.Term;
import jason.environment.Environment;

import java.io.BufferedReader;
import java.io.File;
import java.io.IOException;
import java.io.InputStreamReader;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class CicdEnvironment extends Environment {
    private Path rootDir;
    private String bashCommand;
    private Path logFile;
    private HttpClient httpClient;
    private ScheduledExecutorService telemetryExecutor;
    private double errorRateHighGt;
    private double latencyP95MsHighGt;
    private double availabilityLowLt;
    private String prometheusUrl;
    private volatile long productionTelemetrySuspendedUntilMillis;
    private final Set<String> oneShotForcedFailuresUsed = ConcurrentHashMap.newKeySet();

    @Override
    public void init(String[] args) {
        rootDir = resolveRootDir();
        bashCommand = resolveBashCommand();
        logFile = rootDir.resolve("bdi").resolve("logs").resolve("cicd_environment.log");
        httpClient = HttpClient.newHttpClient();
        prometheusUrl = System.getenv().getOrDefault("BDI_PROMETHEUS_URL", "http://localhost:9090");
        loadThresholds();
        log("[CicdEnvironment] root=" + rootDir);
        log("[CicdEnvironment] bash=" + bashCommand);
        log("[CicdEnvironment] prometheus_url=" + prometheusUrl);
        startTelemetryPolling();
    }

    @Override
    public void stop() {
        if (telemetryExecutor != null) {
            telemetryExecutor.shutdownNow();
        }
        super.stop();
    }

    @Override
    public boolean executeAction(String agentName, Structure action) {
        String functor = action.getFunctor();
        try {
            switch (functor) {
                case "build":
                    requireArity(action, 1);
                    runStage("build", "status(build, %s)", "build.sh", atom(action.getTerm(0)));
                    return true;
                case "test":
                    requireArity(action, 1);
                    runStage("test", "status(test, %s)", "test.sh", atom(action.getTerm(0)));
                    return true;
                case "security_scan":
                    requireArity(action, 1);
                    runStage("security_scan", "status(security_scan, %s)", "security_scan.sh", atom(action.getTerm(0)));
                    return true;
                case "deploy":
                    requireArity(action, 2);
                    runDeploy(atom(action.getTerm(0)), atom(action.getTerm(1)));
                    return true;
                case "health_check":
                    requireArity(action, 1);
                    runHealthCheck(atom(action.getTerm(0)));
                    return true;
                case "rollback":
                    requireArity(action, 1);
                    runRollback(atom(action.getTerm(0)));
                    return true;
                case "record_decision":
                    recordDecision(action);
                    return true;
                default:
                    log("[CicdEnvironment] unsupported action: " + action);
                    return false;
            }
        } catch (Exception exc) {
            log("[CicdEnvironment] action failed before script execution: " + action + " -> " + exc.getMessage());
            return false;
        }
    }

    private void runStage(String stage, String perceptPattern, String scriptName, String version) throws IOException, InterruptedException {
        int exitCode = forcedFailure(stage) ? forcedFailureExitCode(stage) : runScript(scriptName, version);
        updateStatus(perceptPattern, exitCode == 0);
        log("[CicdEnvironment] percept " + String.format(perceptPattern, status(exitCode == 0)));
    }

    private void runDeploy(String candidate, String environment) throws IOException, InterruptedException {
        String stage = "deploy_" + environment;
        suspendTelemetryIfProduction(environment);
        int exitCode = forcedFailure(stage) ? forcedFailureExitCode(stage) : runScript("deploy.sh", environment, candidate);
        suspendTelemetryIfProduction(environment);
        String pattern = "status(deploy(" + environment + "), %s)";
        updateStatus(pattern, exitCode == 0);
        log("[CicdEnvironment] percept " + String.format(pattern, status(exitCode == 0)));
    }

    private void runHealthCheck(String environment) throws IOException, InterruptedException {
        String stage = "health_check_" + environment;
        int exitCode = forcedFailure(stage) ? forcedFailureExitCode(stage) : runScript("health_check.sh", environment);
        String statusPattern = "status(health_check(" + environment + "), %s)";
        updateStatus(statusPattern, exitCode == 0);
        log("[CicdEnvironment] percept " + String.format(statusPattern, status(exitCode == 0)));

        String envPattern = "environment(" + environment + ", %s)";
        updateStatus(envPattern, exitCode == 0, "stable", "unstable");
        log("[CicdEnvironment] percept " + String.format(envPattern, exitCode == 0 ? "stable" : "unstable"));
    }

    private void runRollback(String environment) throws IOException, InterruptedException {
        String stage = "rollback_" + environment;
        suspendTelemetryIfProduction(environment);
        int exitCode = forcedFailure(stage) ? forcedFailureExitCode(stage) : runScript("rollback.sh", environment);
        suspendTelemetryIfProduction(environment);
        String rollbackPattern = "status(rollback(" + environment + "), %s)";
        updateStatus(rollbackPattern, exitCode == 0);
        log("[CicdEnvironment] percept " + String.format(rollbackPattern, status(exitCode == 0)));

        if (exitCode == 0) {
            String envPattern = "environment(" + environment + ", %s)";
            updateStatus(envPattern, true, "stable", "unstable");
            log("[CicdEnvironment] percept " + String.format(envPattern, "stable"));
        }
    }

    private void recordDecision(Structure action) {
        if (action.getArity() == 1) {
            log("[CicdEnvironment][decision] " + atom(action.getTerm(0)));
        } else if (action.getArity() == 2) {
            log("[CicdEnvironment][decision] " + atom(action.getTerm(0)) + " reason=" + atom(action.getTerm(1)));
        } else {
            log("[CicdEnvironment][decision] invalid_record_decision_arity=" + action.getArity());
        }
    }

    private int runScript(String scriptName, String... args) throws IOException, InterruptedException {
        Path script = rootDir.resolve("cicd").resolve("actions").resolve(scriptName);
        List<String> command = new ArrayList<>();
        command.add(bashCommand);
        command.add(script.toString());
        command.addAll(List.of(args));

        log("[CicdEnvironment] action " + String.join(" ", command));
        ProcessBuilder builder = new ProcessBuilder(command);
        builder.directory(rootDir.toFile());
        builder.redirectErrorStream(true);

        Process process = builder.start();
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
            String line;
            while ((line = reader.readLine()) != null) {
                log("[CicdEnvironment][script] " + line);
            }
        }

        int exitCode = process.waitFor();
        log("[CicdEnvironment] exit_code=" + exitCode + " script=" + scriptName);
        return exitCode;
    }

    private void startTelemetryPolling() {
        if (!truthy(System.getenv().getOrDefault("BDI_TELEMETRY_ENABLED", "true"))) {
            log("[CicdEnvironment][telemetry] disabled by BDI_TELEMETRY_ENABLED");
            return;
        }

        int intervalSeconds = parseInt(System.getenv("BDI_TELEMETRY_INTERVAL_SECONDS"), 10);
        telemetryExecutor = Executors.newSingleThreadScheduledExecutor(runnable -> {
            Thread thread = new Thread(runnable, "bdi-telemetry-poller");
            thread.setDaemon(true);
            return thread;
        });
        telemetryExecutor.scheduleWithFixedDelay(
            () -> pollTelemetry("production"),
            2,
            Math.max(1, intervalSeconds),
            TimeUnit.SECONDS
        );
        log("[CicdEnvironment][telemetry] polling enabled interval_seconds=" + Math.max(1, intervalSeconds));
    }

    private void pollTelemetry(String environment) {
        try {
            if (environment.equals("production") && System.currentTimeMillis() < productionTelemetrySuspendedUntilMillis) {
                log("[CicdEnvironment][telemetry] skipped production poll during deployment grace window");
                return;
            }

            double errorRate = queryPrometheus(errorRateQuery(environment));
            double latencyP95Ms = queryPrometheus(latencyP95MsQuery(environment));
            double availability = queryPrometheus(availabilityQuery(environment));

            clearTelemetryUnavailable(environment);

            String errorState = errorRate > errorRateHighGt ? "high" : "normal";
            String latencyState = latencyP95Ms > latencyP95MsHighGt ? "high" : "normal";
            String availabilityState = availability < availabilityLowLt ? "low" : "high";
            boolean unstable = errorState.equals("high") || latencyState.equals("high") || availabilityState.equals("low");

            updateMetric(environment, "error_rate", errorState);
            updateMetric(environment, "latency", latencyState);
            updateMetric(environment, "availability", availabilityState);
            updateStatus("environment(" + environment + ", %s)", !unstable, "stable", "unstable");

            log(String.format(
                Locale.ROOT,
                "[CicdEnvironment][telemetry] %s error_rate=%.4f(%s) latency_p95_ms=%.2f(%s) availability=%.4f(%s) environment=%s",
                environment,
                errorRate,
                errorState,
                latencyP95Ms,
                latencyState,
                availability,
                availabilityState,
                unstable ? "unstable" : "stable"
            ));
        } catch (Exception exc) {
            updateTelemetryUnavailable(environment);
            log("[CicdEnvironment][telemetry] poll_failed environment=" + environment + " reason=" + exc.getMessage());
        }
    }

    private void clearTelemetryUnavailable(String environment) {
        removePercept(Literal.parseLiteral("telemetry(" + environment + ", unavailable)"));
        removePercept(Literal.parseLiteral("network(" + environment + ", suspected)"));
    }

    private void updateTelemetryUnavailable(String environment) {
        addPercept(Literal.parseLiteral("telemetry(" + environment + ", unavailable)"));
        addPercept(Literal.parseLiteral("network(" + environment + ", suspected)"));
        updateStatus("environment(" + environment + ", %s)", false, "stable", "unstable");
        log("[CicdEnvironment] percept telemetry(" + environment + ", unavailable)");
        log("[CicdEnvironment] percept network(" + environment + ", suspected)");
        log("[CicdEnvironment] percept environment(" + environment + ", unstable)");
    }

    private void updateMetric(String environment, String metricName, String value) {
        String pattern = "metric(" + environment + ", " + metricName + ", %s)";
        if (metricName.equals("availability")) {
            removePercept(Literal.parseLiteral(String.format(pattern, "high")));
            removePercept(Literal.parseLiteral(String.format(pattern, "low")));
        } else {
            removePercept(Literal.parseLiteral(String.format(pattern, "high")));
            removePercept(Literal.parseLiteral(String.format(pattern, "normal")));
        }
        addPercept(Literal.parseLiteral(String.format(pattern, value)));
    }

    private double queryPrometheus(String query) throws IOException, InterruptedException {
        String encoded = URLEncoder.encode(query, StandardCharsets.UTF_8);
        URI uri = URI.create(prometheusUrl.replaceAll("/+$", "") + "/api/v1/query?query=" + encoded);
        HttpRequest request = HttpRequest.newBuilder(uri).timeout(java.time.Duration.ofSeconds(10)).GET().build();
        HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
        if (response.statusCode() < 200 || response.statusCode() >= 300) {
            throw new IOException("HTTP " + response.statusCode());
        }
        return firstPrometheusValue(response.body());
    }

    private double firstPrometheusValue(String body) {
        Matcher matcher = Pattern.compile("\"value\"\\s*:\\s*\\[\\s*[-0-9.Ee]+\\s*,\\s*\"([-0-9.Ee]+)\"").matcher(body);
        if (!matcher.find()) {
            return 0.0;
        }
        try {
            double value = Double.parseDouble(matcher.group(1));
            return Double.isFinite(value) ? value : 0.0;
        } catch (NumberFormatException exc) {
            return 0.0;
        }
    }

    private String errorRateQuery(String environment) {
        String selector = "environment=\"" + environment + "\",endpoint=~\"/pay|/refund\"";
        return "sum(payment_service_errors_total{" + selector + "}) / clamp_min(sum(payment_service_requests_total{" + selector + "}), 1)";
    }

    private String latencyP95MsQuery(String environment) {
        String selector = "environment=\"" + environment + "\",endpoint=~\"/pay|/refund\"";
        return "histogram_quantile(0.95, sum by (le) (payment_service_request_latency_seconds_bucket{" + selector + "})) * 1000";
    }

    private String availabilityQuery(String environment) {
        return "avg(payment_service_health{environment=\"" + environment + "\"})";
    }

    private void loadThresholds() {
        Map<String, Double> defaults = Map.of(
            "error_rate_high_gt", 0.05,
            "latency_p95_ms_high_gt", 500.0,
            "availability_low_lt", 0.99
        );
        errorRateHighGt = defaults.get("error_rate_high_gt");
        latencyP95MsHighGt = defaults.get("latency_p95_ms_high_gt");
        availabilityLowLt = defaults.get("availability_low_lt");

        Path thresholdFile = rootDir.resolve("telemetry").resolve("thresholds.yml");
        if (!Files.exists(thresholdFile)) {
            log("[CicdEnvironment][telemetry] thresholds file missing; using defaults");
            return;
        }

        try {
            for (String rawLine : Files.readAllLines(thresholdFile, StandardCharsets.UTF_8)) {
                String line = rawLine.trim();
                if (line.isEmpty() || line.startsWith("#") || !line.contains(":")) {
                    continue;
                }
                String[] parts = line.split(":", 2);
                String key = parts[0].trim();
                double value = Double.parseDouble(parts[1].trim());
                if (key.equals("error_rate_high_gt")) {
                    errorRateHighGt = value;
                } else if (key.equals("latency_p95_ms_high_gt")) {
                    latencyP95MsHighGt = value;
                } else if (key.equals("availability_low_lt")) {
                    availabilityLowLt = value;
                }
            }
            log("[CicdEnvironment][telemetry] thresholds error_rate_high_gt=" + errorRateHighGt
                + " latency_p95_ms_high_gt=" + latencyP95MsHighGt
                + " availability_low_lt=" + availabilityLowLt);
        } catch (Exception exc) {
            log("[CicdEnvironment][telemetry] threshold_read_failed; using defaults reason=" + exc.getMessage());
        }
    }

    private int parseInt(String value, int defaultValue) {
        if (value == null || value.trim().isEmpty()) {
            return defaultValue;
        }
        try {
            return Integer.parseInt(value.trim());
        } catch (NumberFormatException exc) {
            return defaultValue;
        }
    }

    private void suspendTelemetryIfProduction(String environment) {
        if (!environment.equals("production")) {
            return;
        }
        int graceSeconds = parseInt(System.getenv("BDI_TELEMETRY_GRACE_SECONDS"), 15);
        productionTelemetrySuspendedUntilMillis = System.currentTimeMillis() + Math.max(0, graceSeconds) * 1000L;
        log("[CicdEnvironment][telemetry] production grace window seconds=" + Math.max(0, graceSeconds));
    }

    private boolean forcedFailure(String stage) {
        String envStage = envName(stage);
        if (truthy(System.getenv("BDI_FORCE_" + envStage + "_FAIL"))) {
            return true;
        }
        if (truthy(System.getenv("BDI_FORCE_" + envStage + "_FAIL_ONCE"))) {
            return oneShotForcedFailuresUsed.add(envStage);
        }
        return false;
    }

    private int forcedFailureExitCode(String stage) {
        log("[CicdEnvironment] forced_failure stage=" + stage + " env=BDI_FORCE_" + envName(stage) + "_FAIL or _FAIL_ONCE");
        return 1;
    }

    private boolean truthy(String value) {
        if (value == null) {
            return false;
        }
        String normalized = value.trim().toLowerCase(Locale.ROOT);
        return normalized.equals("1") || normalized.equals("true") || normalized.equals("yes") || normalized.equals("on");
    }

    private String envName(String stage) {
        return stage.toUpperCase(Locale.ROOT).replace('-', '_');
    }

    private void updateStatus(String pattern, boolean passed) {
        updateStatus(pattern, passed, "passed", "failed");
    }

    private void updateStatus(String pattern, boolean passed, String passedAtom, String failedAtom) {
        removePercept(Literal.parseLiteral(String.format(pattern, passedAtom)));
        removePercept(Literal.parseLiteral(String.format(pattern, failedAtom)));
        addPercept(Literal.parseLiteral(String.format(pattern, passed ? passedAtom : failedAtom)));
    }

    private String status(boolean passed) {
        return passed ? "passed" : "failed";
    }

    private void requireArity(Structure action, int expected) {
        if (action.getArity() != expected) {
            throw new IllegalArgumentException(action.getFunctor() + " expects " + expected + " argument(s)");
        }
    }

    private String atom(Term term) {
        return term.toString().replace("\"", "").toLowerCase(Locale.ROOT);
    }

    private Path resolveRootDir() {
        Path cwd = Path.of(System.getProperty("user.dir")).toAbsolutePath().normalize();
        if (Files.exists(cwd.resolve("cicd").resolve("actions"))) {
            return cwd;
        }
        if (cwd.getFileName() != null && cwd.getFileName().toString().equals("bdi")) {
            Path parent = cwd.getParent();
            if (parent != null && Files.exists(parent.resolve("cicd").resolve("actions"))) {
                return parent;
            }
        }
        Path parent = cwd.getParent();
        if (parent != null && Files.exists(parent.resolve("cicd").resolve("actions"))) {
            return parent;
        }
        return cwd;
    }

    private String resolveBashCommand() {
        String windowsGitBash = "C:\\Program Files\\Git\\bin\\bash.exe";
        if (new File(windowsGitBash).exists()) {
            return windowsGitBash;
        }
        return "bash";
    }

    private void log(String message) {
        System.out.println(message);
        if (logFile == null) {
            return;
        }
        try {
            Files.createDirectories(logFile.getParent());
            Files.writeString(
                logFile,
                message + System.lineSeparator(),
                StandardCharsets.UTF_8,
                StandardOpenOption.CREATE,
                StandardOpenOption.APPEND
            );
        } catch (IOException ignored) {
            // Console logging still works if file logging is unavailable.
        }
    }
}
