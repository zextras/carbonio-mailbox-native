library(
        identifier: 'jenkins-lib-common@ci-semantic-release',
        retriever: modernSCM([
                $class: 'GitSCMSource',
                credentialsId: 'jenkins-integration-with-github-account',
                remote: 'git@github.com:zextras/jenkins-lib-common.git',
        ])
)

properties(defaultPipelineProperties())

boolean isBuildingTag() {
    return env.TAG_NAME ? true : false
}

String profile = isBuildingTag() ? '-Pprod' : ''

pipeline {
    agent {
        node {
            label 'zextras-v1'
        }
    }

    environment {
        MVN_OPTS = "-Ddebug=0 ${profile}"
        GITHUB_BOT_PR_CREDS = credentials('jenkins-integration-with-github-account')
        JAVA_OPTS = '-Dfile.encoding=UTF8'
        LC_ALL = 'C.UTF-8'
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '25'))
        skipDefaultCheckout()
        timeout(time: 2, unit: 'HOURS')
    }

    triggers {
        cron(env.BRANCH_NAME == 'devel' ? 'H 5 * * *' : '')
    }

    stages {
        stage('Setup') {
            steps {
                checkout scm
                script {
                    gitMetadata()
                }
            }
        }

        stage('Build') {
            steps {
                container('jdk-21') {
                    sh """
                        apt update && apt install -y build-essential
                        mvn ${MVN_OPTS} clean install
                        cp src/main/native/*.c package/
                        cp src/main/native/*.h package/
                        cp target/*.h package/
                    """
                }
            }
        }

        stage('Sonarqube Analysis') {
            steps {
                container('jdk-21') {
                    withSonarQubeEnv(credentialsId: 'sonarqube-user-token', installationName: 'SonarQube instance') {
                        sh """
                            mvn ${MVN_OPTS} -DskipTests \
                                org.sonarsource.scanner.maven:sonar-maven-plugin:sonar \
                                -Dsonar.junit.reportPaths=target/surefire-reports,target/failsafe-reports
                        """
                    }
                }
            }
        }

        stage('Publish SNAPSHOT to maven') {
            when {
                not { buildingTag() }
            }
            steps {
                container('jdk-21') {
                    withCredentials([file(credentialsId: 'jenkins-maven-settings.xml', variable: 'SETTINGS_PATH')]) {
                        script {
                            sh "mvn ${MVN_OPTS} -s " + SETTINGS_PATH + " deploy -DskipTests=true"
                        }
                    }
                }
            }
        }

        stage('Publish to maven') {
            when {
                buildingTag()
            }
            steps {
                container('jdk-21') {
                    withCredentials([file(credentialsId: 'jenkins-maven-settings.xml', variable: 'SETTINGS_PATH')]) {
                        script {
                            sh "mvn ${MVN_OPTS} -s " + SETTINGS_PATH + " deploy -Dchangelist= -DskipTests=true"
                        }
                    }
                }
            }
        }

        stage('Build deb/rpm') {
            steps {
                echo 'Building deb/rpm packages'
                withCredentials([
                    usernamePassword(
                        credentialsId: 'artifactory-jenkins-gradle-properties-splitted',
                        passwordVariable: 'SECRET',
                        usernameVariable: 'USERNAME'
                    )
                ]) {
                    script {
                        env.REPO_ENV = env.GIT_TAG ? 'rc' : 'devel'
                    }

                    buildStage([
                        buildFlags: '-s',
                        prepare: true,
                        overrides: [
                            'ubuntu-jammy': [
                                preBuildScript: '''
                                    echo "machine zextras.jfrog.io" >> auth.conf
                                    echo "login $USERNAME" >> auth.conf
                                    echo "password $SECRET" >> auth.conf
                                    mv auth.conf /etc/apt
                                    echo "deb [trusted=yes] https://zextras.jfrog.io/artifactory/ubuntu-''' + env.REPO_ENV + ''' jammy main" > zextras.list
                                    mv *.list /etc/apt/sources.list.d/
                                    apt-get update
                                '''
                            ],
                            'ubuntu-noble': [
                                preBuildScript: '''
                                    echo "machine zextras.jfrog.io" >> auth.conf
                                    echo "login $USERNAME" >> auth.conf
                                    echo "password $SECRET" >> auth.conf
                                    mv auth.conf /etc/apt
                                    echo "deb [trusted=yes] https://zextras.jfrog.io/artifactory/ubuntu-''' + env.REPO_ENV + ''' noble main" > zextras.list
                                    mv *.list /etc/apt/sources.list.d/
                                    apt-get update
                                '''
                            ],
                            'rocky-8': [
                                preBuildScript: '''
                                    echo "[Zextras]" > zextras.repo
                                    echo "name=Zextras" >> zextras.repo
                                    echo "baseurl=https://$USERNAME:$SECRET@zextras.jfrog.io/artifactory/centos8-''' + env.REPO_ENV + '''/" >> zextras.repo
                                    echo "enabled=1" >> zextras.repo
                                    echo "gpgcheck=0" >> zextras.repo
                                    echo "gpgkey=https://$USERNAME:$SECRET@zextras.jfrog.io/artifactory/centos8-''' + env.REPO_ENV + '''/repomd.xml.key" >> zextras.repo
                                    mv *.repo /etc/yum.repos.d/
                                '''
                            ],
                            'rocky-9': [
                                preBuildScript: '''
                                    echo "[Zextras]" > zextras.repo
                                    echo "name=Zextras" >> zextras.repo
                                    echo "baseurl=https://$USERNAME:$SECRET@zextras.jfrog.io/artifactory/rhel9-''' + env.REPO_ENV + '''/" >> zextras.repo
                                    echo "enabled=1" >> zextras.repo
                                    echo "gpgcheck=0" >> zextras.repo
                                    echo "gpgkey=https://$USERNAME:$SECRET@zextras.jfrog.io/artifactory/rhel9-''' + env.REPO_ENV + '''/repomd.xml.key" >> zextras.repo
                                    mv *.repo /etc/yum.repos.d/
                                '''
                            ],
                        ]
                    ])
                }
            }
        }

        stage('Upload artifacts') {
            when {
                expression { return uploadStage.shouldUpload() }
            }
            tools {
                jfrog 'jfrog-cli'
            }
            steps {
                uploadStage(
                        packages: yapHelper.resolvePackageNames()
                )
            }
        }

        stage('Bump version') {
            steps {
                script {
                    semanticRelease()
                }
            }
        }
    }
}
