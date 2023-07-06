## SQL Server testing with VSC

[This test project](https://github.com/ApiLogicServer/beta) illustrates ***failures to load the VSCode Python extension in devcontainers specifying odbc and arm***.  

&nbsp;

### TL;DR

I created this [apilogicserver/api_logic_server_arm_x image **with odbc**](https://github.com/ApiLogicServer/ApiLogicServer-src/blob/main/docker/api_logic_server_arm_x.Dockerfile), which note includes `FROM --platform=linux/amd64`for odbc.

    - odbc operates, but 
    - fails to load Python VSC (sometimes hangs, sometimes disabled)

[This test project](https://github.com/ApiLogicServer/beta) illustrates ***failures to load the VSCode Python extension in devcontainers specifying odbc and arm***.  

For more details, [click here](#docker-arm-fails).

Submitted [this issue](https://github.com/microsoft/vscode-python/issues/21554).

* 7/5: as suggested, updated `.devcontainer/devcontainer.json` - still not loading.
    * See .devcontainer/log.txt
    * Extension disabled: 
    ![Unable to load Python - extension dsiabled](images/vscode/python-disabled.png)  

* 7/6: as further suggested, updated `.devcontainer/devcontainer.json` - still not loading.

```
	"customizations": {
		// Configure properties specific to VS Code.
		"vscode": {
			// Set default container specific settings.json values on container create.
			"settings": {},
			"extensions": ["ms-python.python"]
		}
	},
```
Appears to hang:

![Python install hangs](images/vscode/python-install-hangs.png)

&nbsp;

---

### Background

While Sql/Server itself runs nicely under docker, there is considerable complexity in installing OCBC.  As further described below, this led to a number of issues:

* `pyodbc` not pip-installed by default

    * This is because installs fail unless odbc is installed, which is complex and might not be needed for all users

* multiple docker images (arm, amd)

* ***failures to load the VSCode Python extension in devcontainers specifying odbc and arm***

I am eager for suggestions to simplify / unify sql/server and odbc usage.  I'd hoped that `mcr.microsoft.com/devcontainers/python:3.11-bullseye` might include odbc, but it did not appear to be the case.  Since this image is considerably larger (1.77G) than python:3.9.4-slim-bullseye (895M), I went with the python versions.

&nbsp;

#### Complex ODBC Setup

As noted above, `pip` installs of pyodbc fail unless the odbc is installed.  Since not all users need odbc, the `pip` install does not include pyodbc.

##### For users

For users requiring pyodbc (SqlServer), there are 2 steps required:

1. ODBC Driver: [using `brew` as described here](https://apilogicserver.github.io/Docs/Install-pyodbc/)

2. `pip install pyodbc==4.0.34`

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

* But, **does not include odbc**, because:

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
