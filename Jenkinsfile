pipeline {
    agent any

       environment {
        SSH_USER = "ubuntu"
        BRANCH_NAME = "env.BRANCH_NAME"
        SSH_HOST = "148.113.6.50"
        SSH_KEY = credentials('jenkins-ssh-key')

        AWS_REGION = "ap-south-1"
        AWS_ACCOUNT_ID = "905418064502"
        AWS_ACCESS_KEY = credentials('aws-access-key-id')
        AWS_SECRET = credentials('aws-secret-access-key')

        ECR_URI = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

        SONAR_HOST_URL = "http://148.113.6.140:9000"
        SONAR_PROJECT_KEY = "GoTrust-Activepieces"
        SONAR_TOKEN = "sqp_dbaa5fb960b35f54502c376a1e6800d6d3ed11c9"
    }

    stages {
        stage('Check Branch') {
            when {
                expression { env.BRANCH_NAME == 'development' }
            }
            steps {
                echo "Running pipeline for development branch"
            }
        }

        stage('Clone Repository & Get Latest Tag') {
            steps {
                script {
                    sh """
                    ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no "${SSH_USER}@${SSH_HOST}" '
                    cd /home/ubuntu/dev_ecr/activepieces && \
                    git fetch --tags && \
                    LATEST_TAG=\$(git describe --tags --abbrev=0 2>/dev/null || echo "v1.0.0") && \
                    echo "Latest Tag: \${LATEST_TAG}" && \
                    echo "\${LATEST_TAG}" > /home/ubuntu/dev_ecr/activepieces/LATEST_TAG
                    '
                    """
                }
            }
        }

        stage('Run SonarQube Analysis') {
            steps {
                script {
                    sh """
                    ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no "${SSH_USER}@${SSH_HOST}" '
                    cd /home/ubuntu/dev_ecr/activepieces && rm -rf /home/ubuntu/dev_ecr/activepieces/.scannerwork && \
                    ~/.sonar/sonar-scanner-6.2.0.4584-linux-x64/bin/sonar-scanner \
                    -Dsonar.projectKey="${SONAR_PROJECT_KEY}" \
                    -Dsonar.host.url="${SONAR_HOST_URL}" \
                    -Dsonar.projectName="GoTrust-Activepieces" \
                    -Dsonar.login="${SONAR_TOKEN}" > sonar_report.txt
                    '
                    """
                }
            }
        }

        stage('Check High Severity Issues') {
            steps {
                script {
                    def criticalIssueCount = sh(
                        script: """
                        ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no "${SSH_USER}@${SSH_HOST}" '
                        BLOCKER_COUNT=\$(curl -s -u ${SONAR_TOKEN}: "${SONAR_HOST_URL}/api/issues/search?componentKeys=${SONAR_PROJECT_KEY}&severities=BLOCKER&resolved=false" | jq -r ".total");
                        CRITICAL_COUNT=\$(curl -s -u ${SONAR_TOKEN}: "${SONAR_HOST_URL}/api/issues/search?componentKeys=${SONAR_PROJECT_KEY}&severities=CRITICAL&resolved=false" | jq -r ".total");
                        echo "Blocker Issues: \${BLOCKER_COUNT}"; echo "Critical Issues: \${CRITICAL_COUNT}";
                        if [ "\${BLOCKER_COUNT}" -gt 0 ] || [ "\${CRITICAL_COUNT}" -gt 0 ]; then 
                            echo "❌ High Severity Issues Found! Aborting deployment."; exit 1; 
                        else 
                            echo "✅ No High Severity Issues Detected. Deployment will continue."; 
                        fi'
                        """,
                        returnStatus: true
                    )

                    if (criticalIssueCount != 0) {
                        error("❌ High Severity Issues Detected. Stopping Pipeline.")
                    } else {
                        echo "✅ No High Severity Issues Detected. Deployment will continue."
                    }
                }
            }
        }

        stage('Build and Trivy Scan Docker Image') {
            steps {
                script {
                    sh """
                    ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no "${SSH_USER}@${SSH_HOST}" '
                    LATEST_TAG=\$(cat /home/ubuntu/dev_ecr/activepieces/LATEST_TAG || echo "latest") && \
                    docker build -t "${ECR_URI}/activepieces:\${LATEST_TAG}" /home/ubuntu/dev_ecr/activepieces && \
                    echo "Running Trivy Scan..." && \
                    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image "${ECR_URI}/activepieces:\${LATEST_TAG}" > /home/ubuntu/dev_ecr/trivy_report.txt 2>&1 && \
                    echo "Trivy scan completed."
                    '
                    """
                }
            }
        }

        stage('Push Docker Image') {
            steps {
                script {
                    sh """
                    ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no "${SSH_USER}@${SSH_HOST}" '
                    LATEST_TAG=\$(cat /home/ubuntu/dev_ecr/activepieces/LATEST_TAG || echo "latest") && \
                    docker tag "${ECR_URI}/activepieces:\${LATEST_TAG}" "${ECR_URI}/activepieces:dev_latest" && \
                    docker push "${ECR_URI}/activepieces:\${LATEST_TAG}" && \
                    docker push "${ECR_URI}/activepieces:dev_latest"
                    '
                    """
                }
            }
        }

        stage('Deploy Activepieces Backend') {
            steps {
                script {
                    sh """
                    ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no "${SSH_USER}@${SSH_HOST}" '
                    cd /home/ubuntu/gotrust_dev/deployment && \
                    docker compose down activepieces && \
                    docker image prune -a -f && \
                    docker compose up activepieces -d --build
                    '
                    """
                }
            }
        }
    }

    post {
        always {
            sh """
            ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no "${SSH_USER}@${SSH_HOST}" '
            if [ ! -s /home/ubuntu/dev_ecr/trivy_report.txt ]; then
                echo "❌ Trivy report missing or empty! Check logs."; exit 1;
            fi'
            """
            echo "Copying Trivy report to Jenkins workspace..."
            sh """
            scp -i "${SSH_KEY}" "${SSH_USER}@${SSH_HOST}:/home/ubuntu/dev_ecr/trivy_report.txt" .
            ls -lah trivy_report.txt
            cat trivy_report.txt
            """
            archiveArtifacts artifacts: 'trivy_report.txt', fingerprint: true
        }
        success {
            echo "✅ Deployment Completed Successfully"
        }
        failure {
            echo "❌ Deployment Failed"
        }
    }
}
