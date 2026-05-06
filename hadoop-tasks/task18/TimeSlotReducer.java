package task18;

import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Reducer;
import java.io.IOException;
import java.util.HashSet;
import java.util.Locale;
import java.util.Set;

/**
 * TimeSlotReducer calculates attendance statistics per valid time slot.
 */
public class TimeSlotReducer extends Reducer<Text, Text, Text, Text> {
    private Text result = new Text();

    /**
     * Counts present/absent records, total valid attendance records, distinct
     * employees, and attendance rate for the given time slot.
     *
     * @param key     the time slot key
     * @param values  iterable of mapper-emitted "employeeId|present" values
     * @param context MapReduce context for emitting attendance statistics
     */
    @Override
    protected void reduce(Text key, Iterable<Text> values, Context context) throws IOException, InterruptedException {
        long presentCount = 0;
        long absentCount = 0;
        long totalRecords = 0;
        Set<String> uniqueEmployees = new HashSet<>();

        for (Text val : values) {
            String[] parts = val.toString().split("\\|", -1);
            if (parts.length != 2) {
                continue;
            }

            String employeeId = parts[0].trim();
            String present = parts[1].trim();
            if (employeeId.isEmpty()) {
                continue;
            }

            uniqueEmployees.add(employeeId);
            totalRecords++;

            if (present.equalsIgnoreCase("Yes")) {
                presentCount++;
            } else if (present.equalsIgnoreCase("No")) {
                absentCount++;
            }
        }

        double attendanceRate = totalRecords == 0 ? 0.0 : (presentCount * 100.0) / totalRecords;
        result.set(String.format(
                Locale.US,
                "Present: %d\tAbsent: %d\tTotal: %d\tUniqueEmployees: %d\tAttendanceRate: %.2f%%",
                presentCount,
                absentCount,
                totalRecords,
                uniqueEmployees.size(),
                attendanceRate
        ));
        context.write(key, result);
    }
}
