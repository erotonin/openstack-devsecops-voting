using System;
using System.Data.Common;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Threading;
using Newtonsoft.Json;
using Npgsql;
using StackExchange.Redis;

namespace Worker
{
    public class Program
    {
        public static int Main(string[] args)
        {
            try
            {
                var dbConnectionString = BuildDbConnectionString();
                var redisConnectionString = BuildRedisConnectionString();
                var pgsql = OpenDbConnection(dbConnectionString);
                var redisConn = OpenRedisConnection(redisConnectionString);
                var redis = redisConn.GetDatabase();

                // Keep alive is not implemented in Npgsql yet. This workaround was recommended:
                // https://github.com/npgsql/npgsql/issues/1214#issuecomment-235828359
                var keepAliveCommand = pgsql.CreateCommand();
                keepAliveCommand.CommandText = "SELECT 1";

                var definition = new { vote = "", voter_id = "" };
                while (true)
                {
                    // Slow down to prevent CPU spike, only query each 100ms
                    Thread.Sleep(100);

                    // Reconnect redis if down
                    if (redisConn == null || !redisConn.IsConnected)
                    {
                        Console.WriteLine("Reconnecting Redis");
                        redisConn = OpenRedisConnection(redisConnectionString);
                        redis = redisConn.GetDatabase();
                    }

                    var entry = redis.ListLeftPopAsync("votes").Result;
                    if (!entry.IsNullOrEmpty)
                    {
                        var json = entry.ToString();
                        var vote = JsonConvert.DeserializeAnonymousType(json, definition);
                        if (vote == null)
                        {
                            Console.Error.WriteLine($"Skipping invalid vote payload: {json}");
                            continue;
                        }

                        Console.WriteLine($"Processing vote for '{vote.vote}' by '{vote.voter_id}'");
                        // Reconnect DB if down
                        if (!pgsql.State.Equals(System.Data.ConnectionState.Open))
                        {
                            Console.WriteLine("Reconnecting DB");
                            pgsql = OpenDbConnection(dbConnectionString);
                        }
                        else
                        { // Normal +1 vote requested
                            UpdateVote(pgsql, vote.voter_id, vote.vote);
                        }
                    }
                    else
                    {
                        keepAliveCommand.ExecuteNonQuery();
                    }
                }
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine(ex.ToString());
                return 1;
            }
        }

        private static NpgsqlConnection OpenDbConnection(string connectionString)
        {
            NpgsqlConnection connection;

            while (true)
            {
                try
                {
                    connection = new NpgsqlConnection(connectionString);
                    connection.Open();
                    break;
                }
                catch (SocketException)
                {
                    Console.Error.WriteLine("Waiting for db");
                    Thread.Sleep(1000);
                }
                catch (DbException)
                {
                    Console.Error.WriteLine("Waiting for db");
                    Thread.Sleep(1000);
                }
            }

            Console.Error.WriteLine("Connected to db");

            var command = connection.CreateCommand();
            command.CommandText = @"CREATE TABLE IF NOT EXISTS votes (
                                        id VARCHAR(255) PRIMARY KEY,
                                        vote VARCHAR(255) NOT NULL
                                    )";
            command.ExecuteNonQuery();

            return connection;
        }

        private static ConnectionMultiplexer OpenRedisConnection(string configuration)
        {
            while (true)
            {
                try
                {
                    Console.Error.WriteLine("Connecting to redis");
                    return ConnectionMultiplexer.Connect(configuration);
                }
                catch (RedisConnectionException)
                {
                    Console.Error.WriteLine("Waiting for redis");
                    Thread.Sleep(1000);
                }
            }
        }

        private static void UpdateVote(NpgsqlConnection connection, string voterId, string vote)
        {
            var command = connection.CreateCommand();
            try
            {
                command.CommandText = "INSERT INTO votes (id, vote) VALUES (@id, @vote)";
                command.Parameters.AddWithValue("@id", voterId);
                command.Parameters.AddWithValue("@vote", vote);
                command.ExecuteNonQuery();
            }
            catch (DbException)
            {
                command.CommandText = "UPDATE votes SET vote = @vote WHERE id = @id";
                command.ExecuteNonQuery();
            }
            finally
            {
                command.Dispose();
            }
        }

        private static string BuildDbConnectionString()
        {
            var host = Environment.GetEnvironmentVariable("DB_HOST") ?? "db";
            var port = Environment.GetEnvironmentVariable("DB_PORT") ?? "5432";
            var user = Environment.GetEnvironmentVariable("DB_USER") ?? "postgres";
            var password = Environment.GetEnvironmentVariable("DB_PASSWORD") ?? "postgres";
            var database = Environment.GetEnvironmentVariable("DB_NAME") ?? "postgres";
            var sslMode = Environment.GetEnvironmentVariable("DB_SSL_MODE") ?? "Disable";
            var trustServerCertificate = Environment.GetEnvironmentVariable("DB_TRUST_SERVER_CERTIFICATE") ?? "true";

            return $"Host={host};Port={port};Username={user};Password={password};Database={database};SSL Mode={sslMode};Trust Server Certificate={trustServerCertificate};";
        }

        private static string BuildRedisConnectionString()
        {
            var host = Environment.GetEnvironmentVariable("REDIS_HOST") ?? "redis";
            var port = Environment.GetEnvironmentVariable("REDIS_PORT") ?? "6379";
            var password = Environment.GetEnvironmentVariable("REDIS_PASSWORD");
            var ssl = Environment.GetEnvironmentVariable("REDIS_SSL") ?? "false";
            var configuration = $"{host}:{port},ssl={ssl.ToLowerInvariant()}";

            if (!string.IsNullOrWhiteSpace(password))
            {
                configuration += $",password={password}";
            }

            return configuration;
        }
    }
}
