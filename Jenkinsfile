pipeline {
    agent any
    environment {
        AWS_CREDS = credentials('aws-credentials-id')
    }
     stages {
        stage('Build & Push') {
           steps {
                sh '''
                  export AWS_ACCESS_KEY_ID=${AWS_CREDS_USR}
                  export AWS_SECRET_ACCESS_KEY=${AWS_CREDS_PSW}
                  $(aws ecr get-login --no-include-email --region us-east-1)
                  docker build -t 176361179303.dkr.ecr.us-east-1.amazonaws.com/hello-service:$BUILD_NUMBER .
                  docker push 176361179303.dkr.ecr.us-east-1.amazonaws.com/hello-service:$BUILD_NUMBER
                '''
            }
        }
        stage('Deploy To EKS') {
            steps {
                sh '''
                export AWS_ACCESS_KEY_ID=${AWS_CREDS_USR}
                export AWS_SECRET_ACCESS_KEY=${AWS_CREDS_PSW}
                aws eks --region us-east-1 update-kubeconfig --name my-eks
                sed -i "s/{BUILD_NUMBER}/$BUILD_NUMBER/g" helm/hello-service/values.yaml
                helm upgrade --install hello-service helm/hello-service
                '''
            }
        }
         stage('Wait till pods are ready') {
             steps {
                 sh '''
                 export AWS_ACCESS_KEY_ID=${AWS_CREDS_USR}
                export AWS_SECRET_ACCESS_KEY=${AWS_CREDS_PSW}
                aws eks --region us-east-1 update-kubeconfig --name my-eks
                 kubectl wait pod --all --for=condition=Ready
                 '''
             }
         }
    }
}
