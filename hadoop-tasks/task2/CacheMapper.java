package task2;

import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.io.LongWritable;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Mapper;

import java.io.BufferedReader;
import java.io.File;
import java.io.IOException;
import java.net.URI;
import java.util.HashMap;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

/**
 * CacheMapper loads the route reference file into a HashMap during setup()
 * using Hadoop's DistributedCache mechanism. For each flight record, it
 * computes revenue = passengerCount * fare and emits (routeLabel, revenue|passengerCount)
 * as a composite value for the reducer to aggregate.
 *
 * The cache path is read from Configuration and resolved against Hadoop's
 * localized cache files exposed by context.getCacheFiles().
 */
public class CacheMapper extends Mapper<LongWritable, Text, Text, Text> {
    private enum MapperCounter {
        CACHE_ROUTES_LOADED,
        CACHE_FILE_NOT_FOUND,
        CACHE_READ_ERROR,
        CACHE_MALFORMED_ROW,
        INPUT_MALFORMED_ROW,
        INPUT_PARSE_ERROR,
        INPUT_NON_POSITIVE,
        UNKNOWN_ROUTE_EMITTED
    }

    /** Route lookup table: routeCode -> "origin-destination" label */
    private final HashMap<String, String> routeMap = new HashMap<>();
    private final Text outKey = new Text();
    private final Text outValue = new Text();

    private String unknownRouteLabel(String routeCode) {
        String normalized = routeCode == null ? "" : routeCode.trim();
        if (normalized.isEmpty()) {
            return "UNKNOWN_MISSING";
        }

        // Collapse repeated UNKNOWN prefixes and then re-add the canonical one.
        String suffix = normalized.replaceFirst("(?i)^(?:UNKNOWN_?)+", "");
        suffix = suffix.replaceFirst("^_+", "").trim();

        if (suffix.isEmpty()) {
            return "UNKNOWN_MISSING";
        }

        return "UNKNOWN_" + suffix;
    }

    /**
     * Loads the route reference file from the DistributedCache into routeMap.
     * The cache file is expected in CSV format: routeCode,origin,destination,distanceKm
     * Each entry is stored as routeCode -> "origin-destination".
     */
    @Override
    protected void setup(Context context) throws IOException, InterruptedException {
        Configuration conf = context.getConfiguration();
        String configuredCachePath = conf.get("cache.path", "").trim();
        String configuredCacheName = configuredCachePath.isEmpty()
                ? ""
                : new File(configuredCachePath).getName();

        URI[] cacheFiles = context.getCacheFiles();
        String cacheFileName = null;

        if (cacheFiles != null && cacheFiles.length > 0) {
            for (URI cacheFile : cacheFiles) {
                String candidate = new File(cacheFile.getPath()).getName();
                if (cacheFileName == null) {
                    cacheFileName = candidate;
                }
                if (!configuredCacheName.isEmpty() && configuredCacheName.equals(candidate)) {
                    cacheFileName = candidate;
                    break;
                }
            }
        }

        if (cacheFileName == null && !configuredCacheName.isEmpty()) {
            cacheFileName = configuredCacheName;
        }

        if (cacheFileName == null || cacheFileName.isEmpty()) {
            context.getCounter(MapperCounter.CACHE_FILE_NOT_FOUND).increment(1L);
            String status = "Cache file missing: no cache.path or distributed cache file available";
            context.setStatus(status);
            System.err.println(status);
            throw new IOException(status);
        }

        Path localizedCachePath = Paths.get(cacheFileName);
        if (!Files.exists(localizedCachePath)) {
            context.getCounter(MapperCounter.CACHE_FILE_NOT_FOUND).increment(1L);
            String status = "Cache file not found in task working directory: " + cacheFileName;
            context.setStatus(status);
            System.err.println(status);
            throw new IOException(status);
        }

        long loadedCount = 0L;
        try (BufferedReader br = Files.newBufferedReader(localizedCachePath, StandardCharsets.UTF_8)) {
            String line;
            while ((line = br.readLine()) != null) {
                String[] parts = line.split(",\\s*", -1);
                if (parts.length < 3) {
                    context.getCounter(MapperCounter.CACHE_MALFORMED_ROW).increment(1L);
                    continue;
                }

                String routeCode = parts[0].trim();
                String origin = parts[1].trim();
                String destination = parts[2].trim();

                if (routeCode.equals("routeCode") || routeCode.isEmpty()) {
                    continue;
                }

                routeMap.put(routeCode, origin + "-" + destination);
                loadedCount++;
            }
        } catch (IOException e) {
            context.getCounter(MapperCounter.CACHE_READ_ERROR).increment(1L);
            String status = "Failed to read cache file: " + cacheFileName + " (" + e.getMessage() + ")";
            context.setStatus(status);
            System.err.println(status);
            throw new IOException(status, e);
        }

        context.getCounter(MapperCounter.CACHE_ROUTES_LOADED).increment(loadedCount);
        String status = "Loaded " + loadedCount + " routes from cache file: " + cacheFileName;
        context.setStatus(status);
        System.out.println(status);
    }

    /**
     * For each flight record, computes revenue and emits (routeLabel, revenue|passengerCount).
     * Skips empty lines, header rows, malformed rows, and non-positive numeric fields.
     * Unknown route codes are emitted with the "UNKNOWN_" prefix.
     *
     * @param key     byte offset of the line in the input file
     * @param value   one line from the flights input file
     * @param context MapReduce context for emitting key-value pairs
     */
    @Override
    protected void map(LongWritable key, Text value, Context context) throws IOException, InterruptedException {
        String line = value.toString().trim();
        if (line.isEmpty() || line.startsWith("flightId") || line.startsWith("flightld")) {
            return;
        }

        try {
            String[] parts = line.split(",\\s*", -1);
            if (parts.length != 4) {
                context.getCounter(MapperCounter.INPUT_MALFORMED_ROW).increment(1L);
                return;
            }

            String routeCode = parts[1].trim();
            String passengerRaw = parts[2].trim();
            String fareRaw = parts[3].trim();

            // Keep blank routeCode rows and normalize them to UNKNOWN_MISSING downstream.
            if (passengerRaw.isEmpty() || fareRaw.isEmpty()) {
                context.getCounter(MapperCounter.INPUT_MALFORMED_ROW).increment(1L);
                return;
            }

            long passengerCount = Long.parseLong(passengerRaw);
            long fare = Long.parseLong(fareRaw);

            if (passengerCount <= 0 || fare <= 0) {
                context.getCounter(MapperCounter.INPUT_NON_POSITIVE).increment(1L);
                return;
            }

            long revenue = passengerCount * fare;
            String routeLabel = routeMap.get(routeCode);
            if (routeLabel == null) {
                routeLabel = unknownRouteLabel(routeCode);
                context.getCounter(MapperCounter.UNKNOWN_ROUTE_EMITTED).increment(1L);
            }

            outKey.set(routeLabel);
            outValue.set(revenue + "|" + passengerCount);
            context.write(outKey, outValue);
        } catch (NumberFormatException e) {
            context.getCounter(MapperCounter.INPUT_PARSE_ERROR).increment(1L);
        }
    }
}
