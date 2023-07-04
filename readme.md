## SQL Server testing with VSC

This project illustrates failures to load the Python extension when the container is configured for amd and odbc12: [click here for more specifics](#docker-arm-fails).

&nbsp;

---

### Background

While Sql/Server itself runs nicely under docker, there is considerable complexity in installing OCBC.  As further described below, this led to a number of issues (ignoring time spent):

* `pyodbc` not pip-installed by default (installs fail unless odbc is installed, which is complex and might not be needed)

* multiple docker images (arm, amd)

* arm image unable to load odbc *and* run in VSCode .devcontainer

I am eager for suggestions to simplify / unify sql/server and odbc usage.  I'd hoped that `mcr.microsoft.com/devcontainers/python:3.11-bullseye` might include odbc, but it did not appear to be the case.  Since this image is considerably larger (1.77G) than python:3.9.4-slim-bullseye (895M), I went with the python versions.

&nbsp;

#### Complex ODBC Setup

As noted above, `pip` installs of pyodbc fail unless the odbc is installed.  Since not all users need odbc, the `pip` install does not include pyodbc.

##### For users

For users requiring pyodbc (SqlServer), there are 2 installs:

* ODBC Driver: [using `brew` as described here](../install-pyodbc)

* `pip install pyodbc==4.0.34`

&nbsp;

##### For ApiLogicServer-dev

ApiLogicServer-dev `requirements.txt` does **not** install odbc.  If you wish to test Sql/Server in ApiLogicServer-dev, follow the user setup instructions above.

&nbsp;

#### Docker

Docker creation provides the opportunity to pre-install odbc and simplify life for Sql/Server users.  After considerable effort, we were able to create dockers with a *consistent* verisons of odbc (v18).  The procedure differs for amd/intel vs. arm, as described below.

&nbsp;

##### Docker amd works

The above instructions depend on `brew`, which is not convenient within a dockerfile.  So, it's installed as follows: [click to see dockerfile](https://github.com/ApiLogicServer/ApiLogicServer-src/blob/main/docker/api_logic_server.Dockerfile).  This works well with Sql/Server, running as a devcontainer under VSCode.

* Note: this took days to discover.  Special thanks to Max Tardideau at [Gallium Data](https://www.galliumdata.com).


&nbsp;

##### Docker arm fails

The standard arm version is installed like this: [click to see dockerfile](https://github.com/ApiLogicServer/ApiLogicServer-src/blob/main/docker/api_logic_server_arm.Dockerfile).  This...

* Works well with VSCode devcontainers, for *non-odbc* databases

* But, **does not include odbc.**

    * Attempting to introduce odbc fails with *ERROR: failed to solve: process "/bin/sh -c ACCEPT_EULA=Y apt-get install -y msodbcsql18" did not complete successfully: exit code: 100*.

odbc inclusion was solved with [this finding](https://stackoverflow.com/questions/71414579/how-to-install-msodbcsql-in-debian-based-dockerfile-with-an-apple-silicon-host), using `FROM --platform=linux/amd64` (special thanks to Joshua Schlichting and Dale K).

So, we created [this dockerfile **with odbc**](https://github.com/ApiLogicServer/ApiLogicServer-src/blob/main/docker/api_logic_server_arm_x.Dockerfile).  Use it with a .devcontainer specifying `FROM apilogicserver/api_logic_server_arm_x`, or use [this test project](https://github.com/ApiLogicServer/beta).

* That does indeed enable odbc access from docker...

* But it ***fails with VSCode*** -- the Python extension is either disabled, or hangs on install (screen shots below).

![Unable to load Python](images/vscode/python-disabled.png)

![Python install hangs](images/vscode/python-install-hangs.png)

* Issue: on start, message: *WARNING: The requested image's platform (linux/amd64) does not match the detected host platform (linux/arm64/v8) and no specific platform was requested*

&nbsp;

#### VSC Bug - Run Configs

VSCode has a bug where it cannot parse Run Configs for SqlSvr:

```bash
zsh: no matches found: --db_url=mssql+pyodbc://sa:Posey3861@localhost:1433/NORTHWND?driver=ODBC+Driver+18+for+SQL+Server&trusted_connection=no&Encrypt=no
```

&nbsp;

### Testing

There are several important testing configurations.

&nbsp;

#### 1. ApiLogicServer-dev

To get around the *VSC bug*, hacks were made to the Run Configs, and the CLI, as described below.

The run config has entries like this:

```
        {
            "name": "SQL Server nw (bypass vsc bug)",
            "type": "python",
            "request": "launch",
            "cwd": "${workspaceFolder}/api_logic_server_cli",
            "program": "cli.py",
            "redirectOutput": true,
            "argsExpansion": "none",
            "args": ["create",
                "--project_name=../../../servers/sqlsvr_nw",
                "--db_url=sqlsvr-nw"
            ],
            "console": "integratedTerminal"
        },
```

The CLI detects db_url's like `sqlsvr-nw`, and converts them to strings like this for [Database Connectivity > Docker Databases](../Database-Connectivity/#docker-databases){:target="_blank" rel="noopener"}:
```
    elif project.db_url == 'sqlsvr-nw':  # work-around - VSCode run config arg parsing
        rtn_abs_db_url = 'mssql+pyodbc://sa:Posey3861@localhost:1433/NORTHWND?driver=ODBC+Driver+18+for+SQL+Server&trusted_connection=no&Encrypt=no'
    elif project.db_url == 'sqlsvr-nw-docker':  # work-around - VSCode run config arg parsing
        rtn_abs_db_url = 'mssql+pyodbc://sa:Posey3861@HOST_IP:1433/NORTHWND?driver=ODBC+Driver+17+for+SQL+Server&trusted_connection=no'
        host_ip = "10.0.0.234"  # ApiLogicServer create  --project_name=/localhost/sqlsvr-nw-docker --db_url=sqlsvr-nw-docker
        if os.getenv('HOST_IP'):
            host_ip = os.getenv('HOST_IP')  # type: ignore # type: str
        rtn_abs_db_url = rtn_abs_db_url.replace("HOST_IP", host_ip)
    elif project.db_url == 'sqlsvr-nw-docker-arm':  # work-around - VSCode run config arg parsing
        rtn_abs_db_url = 'mssql+pyodbc://sa:Posey3861@10.0.0.77:1433/NORTHWND?driver=ODBC+Driver+18+for+SQL+Server&trusted_connection=no&Encrypt=no'
        host_ip = "10.0.0.77"  # ApiLogicServer create  --project_name=/localhost/sqlsvr-nw-docker --db_url=sqlsvr-nw-docker-arm
        if os.getenv('HOST_IP'):
            host_ip = os.getenv('HOST_IP')  # type: ignore # type: str
        rtn_abs_db_url = rtn_abs_db_url.replace("HOST_IP", host_ip)
```

So, on ApiLogicServer-dev:

1. Verify your machine has odbc **18** (using `brew which`)
2. Use **Run Config:** `SQL Server nw (bypass vsc bug)`

&nbsp;


#### 2. Local `pip` install

Note: since the docker image is odbc17, the following commands fail in docker, but run in pip install when you've installed odbc18:

```
ApiLogicServer create --project_name=sqlsvr-nw --db_url=sqlsvr-nw
```

#### 3. Docker (ARM pending)

You can run a ***Docker with ODBC*** (pending for arm with VSC):

```
# arm docker uses odbc18 (note the quotes around the db_url):
ApiLogicServer create  --project_name=/localhost/sqlserver --db_url='mssql+pyodbc://sa:Posey3861@10.0.0.77:1433/NORTHWND?driver=ODBC+Driver+18+for+SQL+Server&trusted_connection=no&Encrypt=no'

# or, using the abbrevation
ApiLogicServer create  --project_name=/localhost/sqlsvr-nw-docker --db_url=sqlsvr-nw-docker-arm

# amd docker requires IP addresses:
ApiLogicServer create --project_name=/localhost/sqlserver --db_url='mssql+pyodbc://sa:Posey3861@10.0.0.234:1433/NORTHWND?driver=ODBC+Driver+18+for+SQL+Server&trusted_connection=no&Encrypt=no'

# or, using the abbreviation (amd):
ApiLogicServer create  --project_name=/localhost/sqlsvr-nw-docker --db_url=sqlsvr-nw-docker
```
