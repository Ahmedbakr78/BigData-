package task2;

import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.conf.Configured;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Job;
import org.apache.hadoop.mapreduce.lib.input.FileInputFormat;
import org.apache.hadoop.mapreduce.lib.output.FileOutputFormat;
import org.apache.hadoop.mapreduce.lib.output.TextOutputFormat;
import org.apache.hadoop.util.Tool;
import org.apache.hadoop.util.ToolRunner;
import java.net.URI;

/**
 * CacheDriver configures and launches the Flight Route Enrichment MapReduce job.
 *
 * Usage: CacheDriver <input-path> <output-path> <cache-path>
 */
public class CacheDriver extends Configured implements Tool {
    @Override
    public int run(String[] args) throws Exception {
        if (args.length != 3) {
            System.err.println("Usage: CacheDriver <input-path> <output-path> <cache-path>");
            return -1;
        }

        Configuration conf = getConf();
        conf.set("cache.path", args[2]);

        Job job = Job.getInstance(conf, "FlightRouteEnrichment");
        job.setJarByClass(CacheDriver.class);
        job.setMapperClass(CacheMapper.class);
        job.setReducerClass(CacheReducer.class);
        job.setOutputKeyClass(Text.class);
        job.setOutputValueClass(Text.class);
        job.setOutputFormatClass(TextOutputFormat.class);

        job.addCacheFile(URI.create(args[2]));

        FileInputFormat.addInputPath(job, new Path(args[0]));
        FileOutputFormat.setOutputPath(job, new Path(args[1]));

        return job.waitForCompletion(true) ? 0 : 1;
    }

    public static void main(String[] args) throws Exception {
        int exitCode = ToolRunner.run(new Configuration(), new CacheDriver(), args);
        System.exit(exitCode);
    }
}
