package task18;

import org.apache.hadoop.io.LongWritable;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Mapper;
import java.io.IOException;

/**
 * TimeSlotMapper extracts employee_id and time_slot from each attendance record.
 * It validates the time slot and presence flag, then emits the canonical slot
 * plus employee/presence details needed for attendance statistics.
 *
 * Output: (time_slot, employee_id|present)
 */
public class TimeSlotMapper extends Mapper<LongWritable, Text, Text, Text> {
    private enum MapperCounter {
        MALFORMED_ROW,
        MISSING_REQUIRED_FIELD,
        INVALID_TIME_SLOT,
        INVALID_PRESENT_VALUE
    }

    private Text outKey = new Text();
    private Text outValue = new Text();

    private String canonicalTimeSlot(String timeSlot) {
        if (timeSlot.equalsIgnoreCase("Morning")) {
            return "Morning";
        }
        if (timeSlot.equalsIgnoreCase("Afternoon")) {
            return "Afternoon";
        }
        if (timeSlot.equalsIgnoreCase("Evening")) {
            return "Evening";
        }
        return null;
    }

    /**
     * Parses each input line and emits (time_slot, employee_id|present).
     * Input format: employee_id,time_slot,present,department,date
     *
     * @param key     byte offset of the line in the input file
     * @param value   one line from the attendance input file
     * @param context MapReduce context for emitting key-value pairs
     */
    @Override
    protected void map(LongWritable key, Text value, Context context) throws IOException, InterruptedException {
        String line = value.toString().trim();
        if (line.isEmpty() || line.startsWith("employee")) {
            return;
        }

        String[] parts = line.split(",\\s*", -1);
        String employeeId;
        String timeSlot;
        String present;

        if (parts.length == 5) {
            employeeId = parts[0].trim();
            timeSlot = parts[1].trim();
            present = parts[2].trim();
        } else if (parts.length >= 8) {
            employeeId = parts[0].trim();
            timeSlot = parts[2].trim();
            present = parts[3].trim();
        } else {
            context.getCounter(MapperCounter.MALFORMED_ROW).increment(1L);
            return;
        }

        if (employeeId.isEmpty() || timeSlot.isEmpty() || present.isEmpty()) {
            context.getCounter(MapperCounter.MISSING_REQUIRED_FIELD).increment(1L);
            return;
        }

        String canonicalSlot = canonicalTimeSlot(timeSlot);
        if (canonicalSlot == null) {
            context.getCounter(MapperCounter.INVALID_TIME_SLOT).increment(1L);
            return;
        }

        String canonicalPresent;
        if (present.equalsIgnoreCase("Yes")) {
            canonicalPresent = "Yes";
        } else if (present.equalsIgnoreCase("No")) {
            canonicalPresent = "No";
        } else {
            context.getCounter(MapperCounter.INVALID_PRESENT_VALUE).increment(1L);
            return;
        }

        outKey.set(canonicalSlot);
        outValue.set(employeeId + "|" + canonicalPresent);
        context.write(outKey, outValue);
    }
}
