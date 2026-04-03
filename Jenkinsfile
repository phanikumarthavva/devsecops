pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }

    parameters {
        string(name: 'BRANCH_NAME', defaultValue: 'main', description: 'Git branch to build')
        string(name: 'IMAGE_REPO', defaultValue: 'phanikumart/devsecops', description: 'Target image repository')
        string(name: 'NAMESPACE', defaultValue: 'static-web', description: 'Kubernetes namespace')
        booleanParam(name: 'DEPLOY', defaultValue: true, description: 'Deploy after push')
    }

    environment {
        APP_NAME     = 'static-web'
        REGISTRY_URL = 'docker.io'
        SHORT_COMMIT = "${env.GIT_COMMIT ? env.GIT_COMMIT.take(7) : 'manual'}"
        IMAGE_TAG    = "${BUILD_NUMBER}"
        FULL_IMAGE   = "${params.IMAGE_REPO}:${BUILD_NUMBER}"
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: "${params.BRANCH_NAME}", url: 'https://github.com/phanikumarthavva/devsecops.git'
            }
        }

        stage('Prepare Metadata') {
            steps {
                script {
                    env.GIT_SHA = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                    env.FULL_IMAGE = "${params.IMAGE_REPO}:${env.BUILD_NUMBER}-${env.GIT_SHA}"
                }
                echo "Image to build: ${env.FULL_IMAGE}"
            }
        }

        stage('Validate') {
            steps {
                sh '''
                    set -e
                    ls -la
                    test -f index.html
                    test -f Dockerfile
                    test -f k8s/deployment.yaml
                    test -f k8s/service.yaml
                '''
            }
        }

        stage('Build') {
            steps {
                sh '''
                    set -e
                    docker build -t ${FULL_IMAGE} .
                '''
            }
        }

        stage('Push') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'docker-registry-creds',
                    usernameVariable: 'REG_USER',
                    passwordVariable: 'REG_PASS'
                )]) {
                    sh '''
                        set -e
                        echo "${REG_PASS}" | docker login -u "${REG_USER}" --password-stdin ${REGISTRY_URL}
                        docker push ${FULL_IMAGE}
                        docker logout ${REGISTRY_URL}
                    '''
                }
            }
        }

        stage('Deploy') {
            when {
                expression { return params.DEPLOY }
            }
            steps {
                sh """
                    set -e
                    chmod +x scripts/deploy.sh
                    sed -i 's|namespace: static-web|namespace: ${params.NAMESPACE}|g' k8s/deployment.yaml
                    sed -i 's|namespace: static-web|namespace: ${params.NAMESPACE}|g' k8s/service.yaml
                    sed -i 's|name: static-web|name: ${params.NAMESPACE}|g' k8s/namespace.yaml || true
                    ./scripts/deploy.sh ${FULL_IMAGE}
                """
            }
        }

        stage('Verify') {
            when {
                expression { return params.DEPLOY }
            }
            steps {
                sh '''
                    set -e
                    kubectl rollout status deployment/static-web -n ${NAMESPACE} --timeout=180s
                    kubectl get all -n ${NAMESPACE}
                '''
            }
        }
    }

    post {
        always {
            sh 'docker image prune -f || true'
        }
        success {
            echo "Success: ${env.FULL_IMAGE}"
        }
        failure {
            echo "Build or deploy failed"
        }
    }
}
