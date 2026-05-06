package task18;

import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.conf.Configured;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Job;
import org.apache.hadoop.mapreduce.lib.input.FileInputFormat;
import org.apache.hadoop.mapreduce.lib.output.FileOutputFormat;
import org.apache.hadoop.util.Tool;
import org.apache.hadoop.util.ToolRunner;

/**
 * TimeSlotDriver configures and launches the Time Slot Partitioning MapReduce job.
 * It registers the custom TimeSlotPartitioner and sets numReduceTasks to 3
 * so Morning, Afternoon, and Evening each land on a dedicated reducer.
 *
 * This produces 3 reducer output files (part-r-00000 through part-r-00002).
 *
 * Usage: TimeSlotDriver <input-path> <output-path>
 */
public class TimeSlotDriver extends Configured implements Tool {
    @Override
    public int run(String[] args) throws Exception {
        if (args.length != 2) {
            System.err.println("Usage: TimeSlotDriver <input-path> <output-path>");
            return -1;
        }
        Job job = Job.getInstance(getConf(), "TimeSlotAttendance");
        job.setJarByClass(TimeSlotDriver.class);
        job.setMapperClass(TimeSlotMapper.class);
        job.setReducerClass(TimeSlotReducer.class);
        job.setPartitionerClass(TimeSlotPartitioner.class);

        // One reducer per valid time slot.
        job.setNumReduceTasks(3);

        job.setOutputKeyClass(Text.class);
        job.setOutputValueClass(Text.class);

        FileInputFormat.addInputPath(job, new Path(args[0]));
        FileOutputFormat.setOutputPath(job, new Path(args[1]));

        return job.waitForCompletion(true) ? 0 : 1;
    }

    public static void main(String[] args) throws Exception {
        int exitCode = ToolRunner.run(new Configuration(), new TimeSlotDriver(), args);
        System.exit(exitCode);
    }
}
