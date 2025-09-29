FROM node:22-trixie-slim

# global installation provides 3nweb executable script
RUN npm install -g spec-3nweb-server

# root for data, and folder with configurations
VOLUME [ "/var/3nweb", "/etc/3nweb", "/etc/letsencrypt" ]

# note that "EXPOSE <port>" is not used, as port is defined in
# conf.yaml file from configurations folder from mounted volume

ENTRYPOINT [ "3nweb" ]
CMD [ "run", "--config", "/etc/3nweb/conf.yaml" ]
