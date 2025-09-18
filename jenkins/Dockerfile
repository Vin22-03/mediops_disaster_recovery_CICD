FROM jenkins/jenkins:lts

USER root

# Set ARG to dynamically pass host Docker group GID during build
ARG DOCKER_GID=1001

# Update and install required packages
RUN apt-get update && apt-get install -y \
    python3 python3-pip \
    docker.io \
    unzip wget curl jq \
    awscli \
    gnupg software-properties-common

# Install kubectl (official v1.29.0 or latest stable)
RUN curl -LO https://dl.k8s.io/release/v1.29.4/bin/linux/amd64/kubectl && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/

# Install Terraform (v1.6.6)
RUN wget https://releases.hashicorp.com/terraform/1.6.6/terraform_1.6.6_linux_amd64.zip && \
    unzip terraform_1.6.6_linux_amd64.zip && \
    mv terraform /usr/local/bin/ && \
    rm terraform_1.6.6_linux_amd64.zip

# Upgrade pip and install Python packages
RUN pip3 install --upgrade pip --break-system-packages && \
    pip3 install pytest --break-system-packages

# 🔐 Install Trivy (vulnerability scanner)
RUN curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin

# 📦 Install Syft (SBOM generator)
RUN curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin

# 🚀 Install SonarScanner (v4.8)
RUN curl -sSLo sonar-scanner.zip https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-4.8.0.2856-linux.zip && \
    unzip sonar-scanner.zip -d /opt && \
    mv /opt/sonar-scanner-* /opt/sonar-scanner && \
    ln -s /opt/sonar-scanner/bin/sonar-scanner /usr/local/bin/sonar-scanner && \
    rm sonar-scanner.zip

# ☕ Install Java 17 (Required for SonarScanner 4.8+)
RUN apt-get update && apt-get install -y openjdk-17-jdk

ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH=$JAVA_HOME/bin:$PATH

# 🛠️ Add Jenkins to Docker group
RUN groupmod -g ${DOCKER_GID} docker || true && \
    usermod -aG docker jenkins

USER jenkins


# Disable setup wizard
ENV JAVA_OPTS -Djenkins.install.runSetupWizard=false

# Pre-create admin user
COPY default-user.groovy /usr/share/jenkins/ref/init.groovy.d/default-user.groovy
