package task2;

import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Reducer;
import java.io.IOException;

/**
 * CacheReducer aggregates totalRevenue and totalPassengers per routeLabel.
 * It receives mapper values in the format "revenue|passengerCount" and emits
 * the canonical tab-separated output expected by the full pipeline.
 */
public class CacheReducer extends Reducer<Text, Text, Text, Text> {
    private Text result = new Text();

    /**
     * Accumulates revenue and passenger counts for all flights sharing the same route label.
     *
     * @param key     the route label (e.g., "Cairo-Dubai")
     * @param values  iterable of composite strings "revenue|passengerCount"
     * @param context MapReduce context for emitting aggregated results
     */
    @Override
    protected void reduce(Text key, Iterable<Text> values, Context context) throws IOException, InterruptedException {
        long totalRevenue = 0;
        long totalPassengers = 0;

        for (Text val : values) {
            String[] parts = val.toString().split("\\|", -1);
            if (parts.length == 2) {
                try {
                    long revenue = Long.parseLong(parts[0]);
                    long passengers = Long.parseLong(parts[1]);

                    totalRevenue += revenue;
                    totalPassengers += passengers;
                } catch (NumberFormatException e) {
                    // Ignore malformed composite values
                }
            }
        }

        result.set(totalRevenue + "\t" + totalPassengers);
        context.write(key, result);
    }
}
