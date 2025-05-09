module.exports = {
  apps: [{
    name: "indexer",
    script: "npm",
    args: "start",
    cwd: "/home/ubuntu/stakingbackend/indexer",  // Replace with your project's path
    env: {
      NODE_ENV: "production",
      REDIS_HOST: "localhost",
      REDIS_PORT: 6379,
    },
    max_memory_restart: "1G",
    log_date_format: "YYYY-MM-DD HH:mm:ss",
    merge_logs: true,
    restart_delay: 10000, // 10 seconds delay between restarts
    max_restarts: 10,     // Maximum number of restarts on crash
  }]
};