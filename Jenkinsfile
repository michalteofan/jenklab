// Variables
def cloud = env.CLOUD ?: "kubernetes"
def serviceAccount = env.SERVICE_ACCOUNT ?: "jenk-jenkins"
def namespace = env.NAMESPACE ?: "labns"
def nodeSelector = env.NODE_SELECTOR ?: "beta.kubernetes.io/arch=ppc64le"
def image = env.IMAGE ?: "nm-mgmt.iic.pl.ibm.com:8500/labns/wordpress:v1.0"
def registry = env.REGISTRY ?: "nm-mgmt.iic.pl.ibm.com:8500"

def dbserver = env.DBSERVER ?: "dbserver"
def dbrootpasswd = env.DBROOTPASSWD ?: "dbrootpasswd"
def dbpassword = env.DBPASSWORD ?: "dbpassword"
def appname = env.APPNAME ?: "appname"

def dbuser = "wpuser"
def dbname = "wpdb"
def vmimage = "RHEL 7.4 LE Base Image"
def flavor = "tiny"
def key = "labkey"
def network = "VPNSEA"

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
        containerTemplate(name: 'jnlp'   , image: 'nm-mgmt.iic.pl.ibm.com:8500/labns/jenkppc64-slave-jnlp:latest', args: '${computer.jnlpmac} ${computer.name}'),
        containerTemplate(name: 'kubectl', image: 'nm-mgmt.iic.pl.ibm.com:8500/labns/kubectl:v1.13.9', ttyEnabled: true, command: 'cat'),
        containerTemplate(name: 'ostackcli' , image: 'nm-mgmt.iic.pl.ibm.com:8500/labns/ostackcli:v1.0', ttyEnabled: true, command: 'cat'),
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
                    sed -i 's/DBUSER/${dbuser}/g' clinit.sh
                    sed -i 's/DBPASSWORD/${env.DBPASSWORD}/g' clinit.sh
                    sed -i 's/DBNAME/${dbname}/g' clinit.sh
                    sed -i 's/DBROOTPASSWD/${env.DBROOTPASSWD}/g' clinit.sh
                    source /ostackrc/pvcjenkinsrc
                    openstack-3 server create --image "${vmimage}" --flavor ${flavor} --key-name ${key} --network ${network} --user-data clinit.sh ${env.DBSERVER} --wait
                    """
                    IP = sh (script: "${env.WORKSPACE}/getip.sh ${env.DBSERVER}", returnStdout: true).trim()
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
                echo 'Ingress created'                
                kubectl --namespace=${env.NAMESPACE} describe ingress -l app=${env.APPNAME}
                
                CFGMAP=`kubectl --namespace=${env.NAMESPACE} get cm -l app=${env.APPNAME} -o name`
                kubectl --namespace=${env.NAMESPACE} get cm
                if [ -z \${CFGMAP} ]; then
                    # No Config Map
                    echo 'Must create a config map'
                    echo "Creating the config map"
                    sed -i 's/APPNAME/${env.APPNAME}/g' wpress-cmap.yaml
                    sed -i 's/DBNAME/${dbname}/g' wpress-cmap.yaml
                    sed -i 's/DBPASSWORD/${env.DBPASSWORD}/g' wpress-cmap.yaml
                    sed -i 's/DBUSER/${dbuser}/g' wpress-cmap.yaml
                    sed -i 's/DBSERVER/${env.IPADDR}/g' wpress-cmap.yaml                                                            
                    kubectl apply -f wpress-cmap.yaml
                fi
                echo 'Service created'                
                kubectl --namespace=${env.NAMESPACE} describe cm -l app=${env.APPNAME}                
                
                DEPLOYMENT=`kubectl --namespace=${env.NAMESPACE} get deployments -l app=${env.APPNAME} -o name`
                kubectl --namespace=${env.NAMESPACE} get deployments
                if [ -z \${DEPLOYMENT} ]; then
                    # No deployment to update
                    echo 'No deployment to update'
                    echo "Starting deployment"
                    sed -i 's/APPNAME/${env.APPNAME}/g' wpress-deploy.yaml
                    sed -i 's~IMAGE~${env.IMAGE}~g' wpress-deploy.yaml
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
