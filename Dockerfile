FROM python:3.8-slim

WORKDIR /usr/src/app/

# Install curl
RUN apt-get update && apt-get install -y curl

# Copy your script into the Docker container
COPY change_domains_ip.sh .

# Make the script executable
RUN chmod +x ./change_domains_ip.sh 

# # Use ENTRYPOINT to set the script as the entry point and CMD to provide arguments
CMD ["bash", "./change_domains_ip.sh", "MAIL", "AUTH_KEY", "3dc0adc7dc84319de8b70ee1070ffd47", "chay-techs.com jenkins.chay-techs.com harbor.chay-techs.com grafana.chay-techs.com kibana.chay-techs.com prometheus.chay-techs.com"]

