package task18;

import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Partitioner;

/**
 * TimeSlotPartitioner distributes mapper output to reducers based on the time_slot key.
 * Each valid time slot (Morning, Afternoon, Evening) is assigned to a dedicated
 * reducer. The mapper filters invalid slots, so the fallback hash path is only a
 * safety net.
 *
 * Partition assignments:
 *   Morning   -> partition 0
 *   Afternoon -> partition 1
 *   Evening   -> partition 2
 */
public class TimeSlotPartitioner extends Partitioner<Text, Text> {
    @Override
    public int getPartition(Text key, Text value, int numPartitions) {
        if (numPartitions <= 0) {
            return 0;
        }

        String slotKey = key.toString();
        if (slotKey.equals("Morning")) {
            return 0 % numPartitions;
        }
        if (slotKey.equals("Afternoon")) {
            return 1 % numPartitions;
        }
        if (slotKey.equals("Evening")) {
            return 2 % numPartitions;
        }
        return Math.abs(slotKey.hashCode()) % numPartitions;
    }
}
