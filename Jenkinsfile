pipeline {
    agent any

    environment {
        RELAY_URL = 'https://k14a103.p.ssafy.io/infra/webhook/jenkins'
        TZ = 'Asia/Seoul'
    }

    stages {
        stage('Init') {
            steps {
                script {
                    env.START_TIME = sh(
                        script: 'date "+%Y-%m-%d %H:%M:%S"',
                        returnStdout: true
                    ).trim()
                    notifyRelay('STARTED')
                }
            }
        }

        stage('Test') {
            steps {
                echo '테스트 단계 (현재 비활성)'
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: '**/build/test-results/test/*.xml, **/junit.xml'
                }
            }
        }
        
        // Jenkins Credentials에서 .env 파일 꺼내 infra/ 폴더에 복사
        stage('Prepare Env') {
            steps {
                withCredentials([
                    file(credentialsId: 'BACKEND_ENV', variable: 'ENV_FILE')
                ]) {
                    sh '''
                        mkdir -p infra
                        rm -f infra/.env
                        cat "$ENV_FILE" > infra/.env
                        chmod 644 infra/.env
                    '''
                }
            }
        }

        // Gradle로 Spring Boot jar 파일 빌드 (테스트 스킵)
        stage('Build') {
            steps {
                dir('be') {
                    sh './gradlew bootJar -x test --no-daemon'
                }
            }
        }

        // 백엔드 이미지 새로 빌드 후 컨테이너 재시작
        stage('Docker Deploy') {
            steps {
                dir('infra') {
                    sh '''
                        docker compose stop backend || true
                        docker compose rm -f backend || true
                        sleep 5
                        docker compose up -d --build backend
                    '''
                }
            }
        }
    }

    post {
        success {
            notifyRelay('SUCCESS')
        }

        failure {
            notifyRelay('FAILURE')
        }

        unstable {
            notifyRelay('UNSTABLE')
        }
    }
}

// 중계서버 알림 전송 로직
def notifyRelay(String status) {
    def endTime = (status == 'STARTED') ? null : sh(
            script: 'date "+%Y-%m-%d %H:%M:%S"',
            returnStdout: true
        ).trim()

    def duration = (status == 'STARTED') ? null : currentBuild.durationString.replace(' and counting', '')

    // GitLab Plugin이 주입하는 env (MR 트리거일 때만 채워짐)
    def mrAuthor    = env.gitlabUserName            ?: env.GIT_AUTHOR_NAME ?: 'unknown'
    def mrUsername  = env.gitlabUserUsername        ?: ''
    def mrBranch    = env.gitlabSourceBranch        ?: env.BRANCH_NAME     ?: ''
    def mrTarget    = env.gitlabTargetBranch        ?: ''
    def mrIid       = env.gitlabMergeRequestIid     ?: ''
    def mrTitle     = env.gitlabMergeRequestTitle   ?: ''
    def mrUrl       = env.gitlabMergeRequestUrl     ?: ''
    def commitFull  = env.gitlabMergeRequestLastCommit ?: env.GIT_COMMIT ?: ''
    def commitShort = commitFull ? commitFull.take(8) : ''

    // 테스트 결과는 종료 시점에만
    def testSummary = (status == 'STARTED') ? null : collectTestSummary()

    def payload = [
        status      : status,
        job_name    : env.JOB_NAME,
        build_number: env.BUILD_NUMBER as Integer,
        build_url   : env.BUILD_URL,
        start_time  : env.START_TIME,
        end_time    : endTime,
        duration    : duration,
        mr: [
            iid     : mrIid,
            title   : mrTitle,
            url     : mrUrl,
            author  : mrAuthor,
            username: mrUsername,
            source  : mrBranch,
            target  : mrTarget
        ],
        commit: [
            short: commitShort,
            full : commitFull
        ],
        test_summary: testSummary
    ]

    // JSON 직렬화 → 파일로 빼서 curl (따옴표/개행 escape 안전)
    def json = groovy.json.JsonOutput.toJson(payload)
    writeFile file: 'mm-payload.json', text: json
    sh """
        curl -sS -X POST \\
          -H 'Content-Type: application/json' \\
          --data @mm-payload.json \\
          ${env.RELAY_URL} || true
    """
}

// JUnit 결과 수집 (신규 실패 = 이번엔 실패인데 직전엔 통과/없던 테스트)
@NonCPS
def collectTestSummary() {
    def summary = [passed: 0, failed: 0, skipped: 0, total: 0, new_failures: 0]
    try {
        def action = currentBuild.rawBuild.getAction(hudson.tasks.junit.TestResultAction.class)
        if (action == null) return summary

        summary.total   = action.totalCount
        summary.failed  = action.failCount
        summary.skipped = action.skipCount
        summary.passed  = summary.total - summary.failed - summary.skipped

        def prev = currentBuild.previousBuild?.rawBuild?.getAction(hudson.tasks.junit.TestResultAction.class)
        if (prev != null) {
            def prevFailed = prev.result.failedTests*.fullName as Set
            def curFailed  = action.result.failedTests*.fullName as Set
            summary.new_failures = (curFailed - prevFailed).size()
        } else {
            summary.new_failures = action.failCount
        }
    } catch (Exception e) {
        echo "테스트 결과 수집 실패: ${e.message}"
    }
    return summary
}