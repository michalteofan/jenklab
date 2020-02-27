// Variables
def cloud = env.CLOUD ?: "kubernetes"
def serviceAccount = env.SERVICE_ACCOUNT ?: "jenk-jenkins"
def namespace = env.NAMESPACE ?: "labns"
def nodeSelector = env.NODE_SELECTOR ?: "beta.kubernetes.io/arch=ppc64le"
def image = env.IMAGE ?: "nm-mgmt.iic.pl.ibm.com:8500/labns/wordpress:v1.0"

def dbserver = env.DBSERVER ?: "dbserver"
def dbname = env.DBNAME ?: "dbname"
def dbuser = env.DBUSER ?: "dbuser"
def dbpass = env.DBPASSWORD ?: "dbpassword"
def dbrootpass = env.DBROOTPASSWD ?: "dbrootpasswd"

def appname = env.APPNAME ?: "appname"
def vmimage = env.VMIMAGE ?: "RHEL 7.4 LE Base Image"
def flavor = env.FLAVOR ?: "tiny"
def key = env.KEY ?: "labkey"
def network = env.NETWORK ?: "VPNSEA"

podTemplate(label: 'buildpod', cloud: cloud, serviceAccount: serviceAccount, namespace: namespace, nodeSelector: nodeSelector, envVars: [
        envVar(key: 'NAMESPACE', value: namespace),
        envVar(key: 'REGISTRY', value: registry),
        envVar(key: 'NODE_SELECTOR', value: nodeSelector)
    ],
    volumes: [
        hostPathVolume(hostPath: '/etc/docker/certs.d', mountPath: '/etc/docker/certs.d'),
        hostPathVolume(hostPath: '/var/run/docker.sock', mountPath: '/var/run/docker.sock'),
        secretVolume(secretName: 'pvcjenkinsrc', mountPath: '/ostackrc'),
        secretVolume(secretName: 'pvccert', mountPath: '/ostackcrt'),
    ],
    containers: [
        containerTemplate(name: 'jnlp'   , image: '${env.REGISTRY}/${env.NAMESPACE}/jenkppc64-slave-jnlp:latest', args: '${computer.jnlpmac} ${computer.name}'),
        containerTemplate(name: 'kubectl', image: '${env.REGISTRY}/${env.NAMESPACE}/kubectl:v1.13.9', ttyEnabled: true, command: 'cat'),
        containerTemplate(name: 'ostackcli' , image: '${env.REGISTRY}/${env.NAMESPACE}/ostackcli:v1.0', ttyEnabled: true, command: 'cat'),
    ]
) 
  
{
    node('buildpod') {
        checkout scm 
                container('ostackcli') {
            stage('Deploy DB using PowerVC') {
                IP = sh (script: "${env.WORKSPACE}/getip.sh ${env.DBSERVER}", returnStdout: true).trim()
                if (!IP?.trim()) {
                    sh """
                    #!/bin/bash
                    sleep 120
                    source /ostackrc/pvcjenkinsrc
                    openstack-3 server create --image ${env.VMIMAGE} --flavor ${env.FLAVOR} --key-name ${env.KEY} --network ${env.VPNSEA} --user-data clinit.sh ${env.DBSERVER} --wait
                    """
                    IP = sh (script: "${env.WORKSPACE}getip.sh ${env.DBSERVER}", returnStdout: true).trim()
                }
                env.IPADDR = IP
                sh "echo IP address: $env.IPADDR"
            }
        }       
        container('kubectl') {
            stage('Deploy New Application on the Cloud') {
                sh """
                SERVICE=`kubectl --namespace=${env.NAMESPACE} get service -l app=${env.APPNAME} -o name`
                kubectl --namespace=${env.NAMESPACE} get services
                if [ -z \${SERVICE} ]; then
                    # No service
                    echo 'Must create a service'
                    echo "Creating the service"
                    sed -i 's/APPNAME/${env.APPNAME}/g' wpress-svc.yaml
                    kubectl apply -f wpress-svc.yaml
                fi
                echo 'Service created'                
                kubectl --namespace=${env.NAMESPACE} describe service -l app=${env.APPNAME}

                INGRESS=`kubectl --namespace=${env.NAMESPACE} get ing -l app=${env.APPNAME} -o name`
                kubectl --namespace=${env.NAMESPACE} get ing
                if [ -z \${INGRESS} ]; then
                    # No ingress
                    echo 'Must create an ingress'
                    echo "Creating the ingress"
                    sed -i 's/APPNAME/${env.APPNAME}/g' wpress-ing.yaml
                    kubectl apply -f wpress-ing.yaml
                fi
                echo 'Service created'                
                kubectl --namespace=${env.NAMESPACE} describe service -l app=${env.APPNAME}
                
                DEPLOYMENT=`kubectl --namespace=${env.NAMESPACE} get deployments -l app=${env.APPNAME} -o name`
                kubectl --namespace=${env.NAMESPACE} get deployments
                if [ -z \${DEPLOYMENT} ]; then
                    # No deployment to update
                    echo 'No deployment to update'
                    echo "Starting deployment"
                    sed -i 's/APPNAME/${env.APPNAME}/g' wpress-deploy.yaml
                    kubectl apply -f wpress-deploy.yaml
                    exit 0
                fi
                kubectl --namespace=${env.NAMESPACE} set image \${DEPLOYMENT} ${env.APPNAME}=${env.IMAGE}
                kubectl --namespace=${env.NAMESPACE} rollout status \${DEPLOYMENT}
                """
            }
        }
    }
}