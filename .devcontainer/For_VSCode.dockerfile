# VSCode uses this file to create a development container, for you to customize and test API Logic Projects.
#
# Per .devcontainer/devcontainer.json, VSCode will offer to open your API Logic Server Project in this docker container
#    Same as: View > Command > Remote-Containers: Open Folder in Container.
#
# https://apilogicserver.github.io/Docs/Working-With-Docker/
#
# FROM: https://github.com/ApiLogicServer/ApiLogicServer-src/blob/main/docker/api_logic_server_arm_x.Dockerfile

FROM apilogicserver/api_logic_server_arm_x
USER api_logic_server
CMD ["bash"]
