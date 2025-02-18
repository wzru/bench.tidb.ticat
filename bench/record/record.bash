set -euo pipefail
. "`cd $(dirname ${BASH_SOURCE[0]}) && pwd`/../../helper/helper.bash"

session="${1}"
env=`cat "${session}/env"`

run_start=`must_env_val "${env}" 'bench.run.start'`
run_end=`must_env_val "${env}" 'bench.run.end'`
version=`must_env_val "${env}" 'tidb.version'`
workload=`must_env_val "${env}" 'bench.workload'`
threads=`must_env_val "${env}" "bench.${workload}.threads"`
score=`must_env_val "${env}" 'bench.run.score'`
tag=`must_env_val "${env}" 'bench.tag'`
bench_start=`env_val "${env}" 'bench.start'`
if [ -z "${bench_start}" ]; then
	bench_start='0'
fi

echo -e "${score}\tworkload=${workload},run_start=${run_start},run_end=${run_end},version=${version},threads=${threads}" >> "${session}/scores"

host=`env_val "${env}" 'bench.meta.host'`
if [ -z "${host}" ]; then
	echo "[:-] no bench.meta.host in env, skipped" >&2
	exit
fi

port=`must_env_val "${env}" 'bench.meta.port'`
db=`must_env_val "${env}" 'bench.meta.db-name'`

function my_exe()
{
	local query="${1}"
	mysql -h "${host}" -P "${port}" -u root --database="${db}" -e "${query}"
}

mysql -h "${host}" -P "${port}" -u root -e "CREATE DATABASE IF NOT EXISTS ${db}"

cols="(                                \
	workload VARCHAR(64),              \
	tag VARCHAR(512),                  \
	bench_start TIMESTAMP,             \
	run_start TIMESTAMP,               \
	run_end TIMESTAMP,                 \
	version VARCHAR(32),               \
	threads INT(11),                   \
	score DOUBLE(6,2),                 \
	PRIMARY KEY(                       \
		workload,                      \
		tag,                           \
		bench_start,                   \
		run_start                      \
	)                                  \
)                                      \
"

# The main score table
my_exe "CREATE TABLE IF NOT EXISTS score ${cols}"

# The detail table, other mods may alter(add cols) it
my_exe "CREATE TABLE IF NOT EXISTS detail ${cols}"

my_exe "\
INSERT INTO score VALUES(              \
	\"${workload}\",                   \
	\"${tag}\",                        \
	FROM_UNIXTIME(${bench_start}),     \
	FROM_UNIXTIME(${run_start}),       \
	FROM_UNIXTIME(${run_end}),         \
	\"${version}\",                    \
	${threads},                        \
	${score}                           \
)                                      \
"
