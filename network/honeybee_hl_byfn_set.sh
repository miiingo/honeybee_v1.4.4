#!/bin/bash

# 기본값; 이 스크립트를 실행하기 전에 이 변수를 내 보냅니다.;
# export HONEYBEE_PROJECT_HOME=$PWD
export BASIC_ARTIFACTS_FOLDER=$HONEYBEE_PROJECT_HOME/artifacts-basic
export BASIC_DOCKER_COMPOSE_FOLDER=$HONEYBEE_PROJECT_HOME/docker-compose-basic
export BASIC_SCRIPTS_FOLDER=$HONEYBEE_PROJECT_HOME/scripts-basic
export TEMPLATES_ARTIFACTS_FOLDER=$HONEYBEE_PROJECT_HOME/artifacts-templates
export TEMPLATES_DOCKER_COMPOSE_FOLDER=$HONEYBEE_PROJECT_HOME/docker-compose-templates
export TEMPLATES_SCRIPTS_FOLDER=$HONEYBEE_PROJECT_HOME/scripts-templates
# export GENERATED_ARTIFACTS_FOLDER=$HONEYBEE_PROJECT_HOME/artifacts
# export GENERATED_DOCKER_COMPOSE_FOLDER=$HONEYBEE_PROJECT_HOME/docker-compose
# export GENERATED_SCRIPTS_FOLDER=$HONEYBEE_PROJECT_HOME/scripts

# [[ -d $GENERATED_ARTIFACTS_FOLDER ]] || mkdir -p $GENERATED_ARTIFACTS_FOLDER/channel-artifacts
# [[ -d $GENERATED_DOCKER_COMPOSE_FOLDER ]] || mkdir -p $GENERATED_DOCKER_COMPOSE_FOLDER/base
# [[ -d $GENERATED_SCRIPTS_FOLDER ]] || mkdir -p $GENERATED_SCRIPTS_FOLDER

# 필수 파라매터 항목: kafka 기준
: ${ORDERER_TYPE="kafka"}
: ${ORG:="org1"}
: ${DOMAIN:="honeybee.com"}
: ${ORDERER_CNT:="3"}
: ${ORG_CNT:="3"}
: ${PEER_CNT:="2"}
: ${BATCH_TIMEOUT="2s"}
: ${MAX_MESSAGE_COUNT="10"}
# : ${CHANNEL_NAME="mychannel"}

: ${IP1:="172.27.42.131"}           # 
: ${IP2:="172.27.42.132"}           # 
: ${IP3:="172.27.42.133"}          # 
: ${IP4:="172.27.42.134"}          # 
: ${IP5:="172.27.42.135"}           # 

: ${ORDERER_PORT:="7050"}
: ${ZOOKEEPER_PORT:="2181"}
: ${KAFKA_PORT:="9092"}
: ${PEER0_PORT:="7051"}
: ${PEER1_PORT:="7056"}
: ${COUCHDB0_PORT:="5984"}
: ${COUCHDB1_PORT:="5884"}
: ${CA_PORT:="7054"}
: ${API_PORT:="4000"}

PEER_CNT=2  # PEER_CNT 값 고정  TODO: 사용자가 설정 가능하도록 변경 예정
HOST_ID=${ORG:3}
main_ip=IP${HOST_ID}
MAIN_IP=${!main_ip}

# 설정 값 출력
function printSettingValue () {
    echo "=================== Setting Values in 'honeybee_hl_byfn_set.sh' ==================="
    echo "ORDERER_TYPE : $ORDERER_TYPE"
    # if [ "${ORDERER_TYPE}" == "solo" ]; then
        # # solo 모드용 변수 세팅
        # DOMAIN="example.com"
        # ORDERER_CNT="1"
        # ORG_CNT="2"
        # PEER_CNT="2"
        # BATCH_TIMEOUT="2s"
        # MAX_MESSAGE_COUNT="10"
    # fi
    echo "DOMAIN : '$DOMAIN'"
    echo "ORDERER_CNT : '$ORDERER_CNT'"
    echo "ORG_CNT : '$ORG_CNT'"
    echo "PEER_CNT : '$PEER_CNT'"
    echo "BATCH_TIMEOUT : '$BATCH_TIMEOUT'"
    echo "MAX_MESSAGE_COUNT : '$MAX_MESSAGE_COUNT'"
    echo "----------------------------------------------------------------------"

    if [ "${ORDERER_TYPE}" == "kafka" ]; then
        echo "ORG : '$ORG'"
        echo "HOST_ID : '$HOST_ID'"
        echo "MAIN_IP : '$MAIN_IP'"
        count=1
        while [ ${count} -le ${ORG_CNT} ]; do
            IP=IP${count}
            echo "IP${count} : ${!IP}"
            count=$(( ${count}+1 ))
        done

        echo "----------------------------------------------------------------------"
        echo "ORDERER_PORT : '$ORDERER_PORT'"
        echo "ZOOKEEPER_PORT : '$ZOOKEEPER_PORT'"
        echo "KAFKA_PORT : '$KAFKA_PORT'"
        echo "PEER0_PORT : '$PEER0_PORT'"
        echo "PEER1_PORT : '$PEER1_PORT'"
        echo "COUCHDB0_PORT : '$COUCHDB0_PORT'"
        echo "COUCHDB1_PORT : '$COUCHDB1_PORT'"
        echo "CA_PORT : '$CA_PORT'"
        echo "API_PORT : '$API_PORT'"
    fi
    echo "==================================================================================="
    echo
}

# solo 모드를 위한 설정 파일 복사
function copyBasicFilesForSolo() {
    echo "Copy basic files for solo"

    # crypto-config.yaml 파일 복사
    basic_file=$BASIC_ARTIFACTS_FOLDER/crypto-config-basic.yaml
    result_file=$GENERATED_ARTIFACTS_FOLDER/crypto-config.yaml
    cp ${basic_file} ${result_file}

    # configtx.yaml 파일 복사
    basic_file=$BASIC_ARTIFACTS_FOLDER/configtx-basic.yaml
    result_file=$GENERATED_ARTIFACTS_FOLDER/configtx.yaml
    cp ${basic_file} ${result_file}

    # network-config.json 파일 복사
    basic_file=$BASIC_ARTIFACTS_FOLDER/network-config-basic.json
    result_file=$GENERATED_ARTIFACTS_FOLDER/network-config.json
    sed -e "s/MAIN_IP/$MAIN_IP/g" ${basic_file} > ${result_file}


    # docker-compose-cli.yaml 파일 복사
    basic_file=$BASIC_DOCKER_COMPOSE_FOLDER/docker-compose-cli-basic.yaml
    result_file=$GENERATED_DOCKER_COMPOSE_FOLDER/docker-compose-cli.yaml
    cp ${basic_file} ${result_file}

    # base/docker-compose-base.yaml 파일 복사
    basic_file=$BASIC_DOCKER_COMPOSE_FOLDER/base/docker-compose-base-basic.yaml
    result_file=$GENERATED_DOCKER_COMPOSE_FOLDER/base/docker-compose-base.yaml
    cp ${basic_file} ${result_file}

    # base/peer-base.yaml 파일 복사
    basic_file=$BASIC_DOCKER_COMPOSE_FOLDER/base/peer-base-basic.yaml
    result_file=$GENERATED_DOCKER_COMPOSE_FOLDER/base/peer-base.yaml
    cp ${basic_file} ${result_file}

    # docker-compose-couch.yaml 파일 복사
    basic_file=$BASIC_DOCKER_COMPOSE_FOLDER/docker-compose-couch-basic.yaml
    result_file=$GENERATED_DOCKER_COMPOSE_FOLDER/docker-compose-couch.yaml
    cp ${basic_file} ${result_file}

    # docker-compose-ca.yaml 파일 복사
    basic_file=$BASIC_DOCKER_COMPOSE_FOLDER/docker-compose-ca-basic.yaml
    result_file=$GENERATED_DOCKER_COMPOSE_FOLDER/docker-compose-ca.yaml
    cp ${basic_file} ${result_file}

    # docker-compose-e2e-template.yaml 파일 복사
    basic_file=$BASIC_DOCKER_COMPOSE_FOLDER/docker-compose-e2e-basic.yaml
    result_file=$GENERATED_DOCKER_COMPOSE_FOLDER/docker-compose-e2e-template.yaml
    cp ${basic_file} ${result_file}

    # docker-compose-api.yaml 파일 복사
    basic_file=$BASIC_DOCKER_COMPOSE_FOLDER/docker-compose-api-basic.yaml
    result_file=$GENERATED_DOCKER_COMPOSE_FOLDER/docker-compose-api.yaml
    cp ${basic_file} ${result_file}

    # base/api-base.yaml 파일 복사
    basic_file=$BASIC_DOCKER_COMPOSE_FOLDER/base/api-base-basic.yaml
    result_file=$GENERATED_DOCKER_COMPOSE_FOLDER/base/api-base.yaml
    cp ${basic_file} ${result_file}


    # scripts/scripts.sh 파일 복사
    basic_file=$BASIC_SCRIPTS_FOLDER/script-basic.sh
    result_file=$GENERATED_SCRIPTS_FOLDER/script.sh
    cp ${basic_file} ${result_file}

    # scripts/utils.sh 파일 복사
    basic_file=$BASIC_SCRIPTS_FOLDER/utils-basic.sh
    result_file=$GENERATED_SCRIPTS_FOLDER/utils.sh
    cp ${basic_file} ${result_file}

}

# 사용자가 설정한 값에 맞게 crypto-config.yaml 파일을 생성하는 함수
function createCryptoConfigYamlFiles() {
    echo "Create crypyo-config.yaml file"

    result_file=$GENERATED_ARTIFACTS_FOLDER/crypto-config.yaml

    # OrdererOrgs 설정
    template_file=$TEMPLATES_ARTIFACTS_FOLDER/crypto-config-OrdererOrgs.yaml
    count=1
    while [ ${count} -le ${ORDERER_CNT} ]; do
        # echo "      - Hostname: orderer.org${count}" >> ${result_file}
        ORDERER_HOST_NAME=$ORDERER_HOST_NAME"      - Hostname: orderer.org${count}\n"
        count=$(( ${count}+1 ))
    done
    sed -e "s/DOMAIN/$DOMAIN/g" \
        -e "s/      - ORDERER_HOST_NAME/$ORDERER_HOST_NAME/g" \
        ${template_file} > ${result_file}

    # PeerOrgs 설정
    template_file=$TEMPLATES_ARTIFACTS_FOLDER/crypto-config-PeerOrgs.yaml
    echo "PeerOrgs:" >> ${result_file}
    count=1
    while [ ${count} -le ${ORG_CNT} ]; do
        sed -e "s/ORG/org${count}/g" \
            -e "s/DOMAIN/$DOMAIN/g" \
            -e "s/PEER_CNT/$PEER_CNT/g" \
            ${template_file} >> ${result_file}
        count=$(( ${count}+1 ))
    done
}

# 사용자가 설정한 값에 맞게 configtx.yaml 파일을 생성하는 함수
function createConfigtxYamlFiles() {
    echo "Create configtx.yaml file"

    result_file=$GENERATED_ARTIFACTS_FOLDER/configtx.yaml

    # Organizations > OrdererOrg 설정
    template_file=$TEMPLATES_ARTIFACTS_FOLDER/configtx-Organizations.yaml
    sed -e "s/DOMAIN/$DOMAIN/g" ${template_file} > ${result_file}

    # Organizations > Org 설정
    template_file=$TEMPLATES_ARTIFACTS_FOLDER/configtx-Organizations-Org.yaml
    count=1
    while [ ${count} -le ${ORG_CNT} ]; do
        sed -e "s/ORG/org${count}/g" \
            -e "s/DOMAIN/$DOMAIN/g" \
            -e "s/PEER_CNT/$PEER_CNT/g" \
            ${template_file} >> ${result_file}
        count=$(( ${count}+1 ))
    done

    # Capabilities 설정
    template_file=$TEMPLATES_ARTIFACTS_FOLDER/configtx-Capabilities.yaml
    cat ${template_file} >> ${result_file}

    # Application 설정
    template_file=$TEMPLATES_ARTIFACTS_FOLDER/configtx-Application.yaml
    cat ${template_file} >> ${result_file}

    # Orderer 설정
    template_file=$TEMPLATES_ARTIFACTS_FOLDER/configtx-Orderer.yaml
    ## 사용자 환경에 맞는 ORDERER_ADDRESSES 세팅
    count=1
    while [ ${count} -le ${ORDERER_CNT} ]; do
        ORDERER_ADDRESSES=$ORDERER_ADDRESSES"        - orderer.org${count}.$DOMAIN:7050\n"
        count=$(( ${count}+1 ))
    done
    ## 사용자 환경에 맞는 KAFKA_BROCKERS 세팅
    if [ "$ORDERER_TYPE" == "kafka" ]; then
        count=1
        KAFKA_BROCKERS=""
        # TODO: kafka, zookeeper 개수도 설정 가능하도록 수정
        # while [ ${count} -le ${ORDERER_CNT} ]; do
        while [ ${count} -le 3 ]; do
            IP=IP${count}
            # echo ${!IP}
            KAFKA_BROCKERS=$KAFKA_BROCKERS"            - ${!IP}:9092\n"
            count=$(( ${count}+1 ))
        done
    else
        KAFKA_BROCKERS="            - 127.0.0.1:9092"
    fi
    sed -e "s/ORDERER_TYPE/$ORDERER_TYPE/g" \
        -e "s/BATCH_TIMEOUT/$BATCH_TIMEOUT/g" \
        -e "s/MAX_MESSAGE_COUNT/$MAX_MESSAGE_COUNT/g" \
        -e "s/        - ORDERER_ADDRESSES/$ORDERER_ADDRESSES/g" \
        -e "s/            - KAFKA_BROCKERS/$KAFKA_BROCKERS/g" \
        ${template_file} >> ${result_file}

    # Channel 설정
    template_file=$TEMPLATES_ARTIFACTS_FOLDER/configtx-Channel.yaml
    cat ${template_file} >> ${result_file}

    # Profiles 설정
    template_file=$TEMPLATES_ARTIFACTS_FOLDER/configtx-Profiles.yaml
    ## 사용자 환경에 맞는 Organizations 세팅
    count=1
    while [ ${count} -le ${ORG_CNT} ]; do
        ORDERER_GENESIS_ORGANIZATIONS=$ORDERER_GENESIS_ORGANIZATIONS"                    - *org${count}\n"
        CHANNEL_ORGANIZATIONS=$CHANNEL_ORGANIZATIONS"                - *org${count}\n"
        KAFKA_ORGANIZATIONS=$KAFKA_ORGANIZATIONS"                - *org${count}\n"
        count=$(( ${count}+1 ))
    done
    ## 사용자 환경에 맞는 KAFKA_BROCKERS 세팅
    if [ "$ORDERER_TYPE" == "kafka" ]; then
        count=1
        KAFKA_BROCKERS=""
        # TODO: kafka, zookeeper 개수도 설정 가능하도록 수정
        # while [ ${count} -le ${ORDERER_CNT} ]; do
        while [ ${count} -le 3 ]; do
            IP=IP${count}
            # echo ${!IP}
            KAFKA_BROCKERS=$KAFKA_BROCKERS"                - ${!IP}:9092\n"
            count=$(( ${count}+1 ))
        done
    else
        KAFKA_BROCKERS="                - kafka.example.com:9092"
    fi
    sed -e "s/                    - ORDERER_GENESIS_ORGANIZATIONS/$ORDERER_GENESIS_ORGANIZATIONS/g" \
        -e "s/                - CHANNEL_ORGANIZATIONS/$CHANNEL_ORGANIZATIONS/g" \
        -e "s/                - KAFKA_BROKERS/$KAFKA_BROCKERS/g" \
        -e "s/                - KAFKA_ORGANIZATIONS/$KAFKA_ORGANIZATIONS/g" \
        ${template_file} >> ${result_file}
}

# 멀티 호스트 간 연결을 위한 hosts 파일 생성
function createHostsFiles() {
    echo "Create hosts files"
    echo
    mkdir -p $GENERATED_ARTIFACTS_FOLDER/hosts
    ORDERER_HOSTS="\n"
    ZOOKEEPER_HOSTS="\n"
    KAFKA_HOSTS="\n"
    PEER_HOSTS="\n"

    count=1
    while [ ${count} -le ${ORDERER_CNT} ]; do
        IP=IP${count}
        # TODO: kafka, zookeeper 개수도 설정 가능하도록 수정
        if [ ${count} -le 3 ]; then
            ZOOKEEPER_HOSTS=$ZOOKEEPER_HOSTS"${!IP} 	zookeeper${count}.$DOMAIN\n"
            KAFKA_HOSTS=$KAFKA_HOSTS"${!IP} 	kafka${count}.$DOMAIN\n"
        fi
        ORDERER_HOSTS=$ORDERER_HOSTS"${!IP} 	orderer.org${count}.$DOMAIN\n"
        count=$(( ${count}+1 ))
    done

    count=1
    while [ ${count} -le ${ORG_CNT} ]; do
        IP=IP${count}
        peer_count=0
        while [ ${peer_count} -lt ${PEER_CNT} ]; do
            PEER_HOSTS=$PEER_HOSTS"${!IP} 	peer${peer_count}.org${count}.$DOMAIN\n"
            peer_count=$(( ${peer_count}+1 ))
        done
        count=$(( ${count}+1 ))
    done

    # cli_hosts 파일 설정
    echo "Create cli_hosts files to cli communication"
    template_file=$TEMPLATES_ARTIFACTS_FOLDER/hosts_template
    result_file=$GENERATED_ARTIFACTS_FOLDER/hosts/cli_hosts
    sed -e "s/HOSTS/$ORDERER_HOSTS$PEER_HOSTS/g" \
        ${template_file} > ${result_file}

    # orderer_hosts 파일 설정
    echo "Create orderer_hosts files to orderer communication"
    template_file=$TEMPLATES_ARTIFACTS_FOLDER/hosts_template
    result_file=$GENERATED_ARTIFACTS_FOLDER/hosts/orderer_hosts
    if [ "$ORDERER_TYPE" == "kafka" ]; then
        sed -e "s/HOSTS/$ORDERER_HOSTS$KAFKA_HOSTS/g" \
            ${template_file} > ${result_file}

        # kafka 연결을 위한 kafka_hosts 파일 설정
        echo "Create kafka_hosts files to zookeeper-kafka communication"
        result_file=$GENERATED_ARTIFACTS_FOLDER/hosts/kafka_hosts
        sed -e "s/HOSTS/$ZOOKEEPER_HOSTS$KAFKA_HOSTS/g" \
            ${template_file} > ${result_file}
    else
        sed -e "s/HOSTS/$ORDERER_HOSTS/g" \
            ${template_file} > ${result_file}
    fi

    # 피어-투-피어 연결을 위한 peer_hosts 파일 설정
    # TODO: 같은 호스트 내에 있는 peer는 hosts 파일에 설정하지 않아야함(2018.07.11) -> 확인 필요
    echo "Create peer_hosts files to peer-to-peer communication"
    # template_file=$TEMPLATES_ARTIFACTS_FOLDER/hosts_template
    result_file=$GENERATED_ARTIFACTS_FOLDER/hosts/peer_hosts
    sed -e "s/HOSTS/$ORDERER_HOSTS$PEER_HOSTS/g" \
        ${template_file} > ${result_file}
    # sed "/peer0.$ORG.$DOMAIN/d" $GENERATED_ARTIFACTS_FOLDER/hosts/cli_hosts > $GENERATED_ARTIFACTS_FOLDER/hosts/peer0_hosts
    # sed "/peer1.$ORG.$DOMAIN/d" $GENERATED_ARTIFACTS_FOLDER/hosts/cli_hosts > $GENERATED_ARTIFACTS_FOLDER/hosts/peer1_hosts


    echo
}


# 사용자가 설정한 값에 맞게 docker-compose.yaml 파일을 생성하는 함수
# TODO: PEER_CNT 값에 맞게 peer 생성
function createDockerComposeYamlFiles() {
    echo "Create docker-compose.yaml files"

    # docker-compose-cli.yaml 파일 생성
    template_file=$TEMPLATES_DOCKER_COMPOSE_FOLDER/docker-compose-cli-template.yaml
    result_file=$GENERATED_DOCKER_COMPOSE_FOLDER/docker-compose-cli.yaml
    sed -e "s/MAIN_ORG/$ORG/g" \
        -e "s/DOMAIN/$DOMAIN/g" \
        ${template_file} > ${result_file}

    # base/docker-compose-base.yaml 파일 생성
    template_file=$TEMPLATES_DOCKER_COMPOSE_FOLDER/base/docker-compose-base-template.yaml
    result_file=$GENERATED_DOCKER_COMPOSE_FOLDER/base/docker-compose-base.yaml
    # sed -e "s/MAIN_ORG/$ORG/g" \
    #     -e "s/DOMAIN/$DOMAIN/g" \
    #     -e "s/IP1/$ORG1_IP/g" \
    #     -e "s/IP2/$ORG2_IP/g" \
    #     -e "s/IP3/$ORG3_IP/g" \
    #     -e "s/IP4/$ORG4_IP/g" \
    #     -e "s/IP5/$ORG5_IP/g" \
    #     -e "s/IP6/$ORG6_IP/g" \
    #     -e "s/ORDERER_PORT/$ORDERER_PORT/g" \
    #     -e "s/PEER0_PORT/$PEER0_PORT/g" \
    #     -e "s/PEER1_PORT/$PEER1_PORT/g" \
    #     ${template_file} >> ${result_file}
    sed -e "s/MAIN_ORG/$ORG/g" \
        -e "s/DOMAIN/$DOMAIN/g" \
        -e "s/ORDERER_PORT/$ORDERER_PORT/g" \
        -e "s/PEER0_PORT/$PEER0_PORT/g" \
        -e "s/PEER1_PORT/$PEER1_PORT/g" \
        ${template_file} > ${result_file}

    # base/peer-base.yaml 파일 생성
    template_file=$TEMPLATES_DOCKER_COMPOSE_FOLDER/base/peer-base.yaml
    result_file=$GENERATED_DOCKER_COMPOSE_FOLDER/base/peer-base.yaml
    cp ${template_file} ${result_file}

    # docker-compose-couch.yaml 파일 생성
    template_file=$TEMPLATES_DOCKER_COMPOSE_FOLDER/docker-compose-couch-template.yaml
    result_file=$GENERATED_DOCKER_COMPOSE_FOLDER/docker-compose-couch.yaml
    sed -e "s/ORG/$ORG/g" \
        -e "s/DOMAIN/$DOMAIN/g" \
        -e "s/COUCHDB0_PORT/$COUCHDB0_PORT/g" \
        -e "s/COUCHDB1_PORT/$COUCHDB1_PORT/g" \
        ${template_file} > ${result_file}

    # docker-compose-ca.yaml 파일 생성
    template_file=$TEMPLATES_DOCKER_COMPOSE_FOLDER/docker-compose-ca-template.yaml
    result_file=$GENERATED_DOCKER_COMPOSE_FOLDER/docker-compose-ca.yaml
    sed -e "s/ORG/$ORG/g" \
        -e "s/DOMAIN/$DOMAIN/g" \
        -e "s/CA_PORT/$CA_PORT/g" \
        ${template_file} > ${result_file}


    # docker-compose-api.yaml 파일 생성
    template_file=$TEMPLATES_DOCKER_COMPOSE_FOLDER/docker-compose-api-template.yaml
    result_file=$GENERATED_DOCKER_COMPOSE_FOLDER/docker-compose-api.yaml
    # sed -e "s/MAIN_ORG/$ORG/g" \
    #     -e "s/MAIN_IP/$MAIN_IP/g" \
    #     -e "s/DOMAIN/$DOMAIN/g" \
    #     -e "s/ORG1/$ORG1/g" \
    #     -e "s/ORG2/$ORG2/g" \
    #     -e "s/ORG3/$ORG3/g" \
    #     -e "s/ORG4/$ORG4/g" \
    #     -e "s/ORG5/$ORG5/g" \
    #     -e "s/ORG6/$ORG6/g" \
    #     -e "s/IP1/$ORG1_IP/g" \
    #     -e "s/IP2/$ORG2_IP/g" \
    #     -e "s/IP3/$ORG3_IP/g" \
    #     -e "s/IP4/$ORG4_IP/g" \
    #     -e "s/IP5/$ORG5_IP/g" \
    #     -e "s/IP6/$ORG6_IP/g" \
    #     -e "s/API_PORT/$API_PORT/g" \
    #     -e "s/MODE_TYPE/$MODE_TYPE/g" \
    #     ${template_file} > ${result_file}
    sed -e "s/MAIN_ORG/$ORG/g" \
        -e "s/MAIN_IP/$MAIN_IP/g" \
        -e "s/DOMAIN/$DOMAIN/g" \
        -e "s/API_PORT/$API_PORT/g" \
        -e "s/MODE_TYPE/$MODE_TYPE/g" \
        ${template_file} > ${result_file}

    # base/api-base.yaml 파일 생성
    template_file=$TEMPLATES_DOCKER_COMPOSE_FOLDER/base/api-base.yaml
    result_file=$GENERATED_DOCKER_COMPOSE_FOLDER/base/api-base.yaml
    cp ${template_file} ${result_file}


    # 1~3번 호스트는 kafka와 zookeeper 컨테이너 실행
    # TODO: kafka, zookeeper 개수도 지정 가능하도록 설정
    if [ "$ORDERER_TYPE" == "kafka" ]; then
        if [ $HOST_ID -le 3 ]; then
            # docker-compose-kafka.yaml 파일 생성
            template_file=$TEMPLATES_DOCKER_COMPOSE_FOLDER/docker-compose-kafka-template.yaml
            result_file=$GENERATED_DOCKER_COMPOSE_FOLDER/docker-compose-kafka.yaml
            # sed -e "s/ORG/$ORG/g" \
            #     -e "s/DOMAIN/$DOMAIN/g" \
            #     -e "s/HOST_ID/$HOST_ID/g" \
            #     -e "s/IMAGE_TAG/$IMAGETAG/g" \
            #     -e "s/IP1/$ORG1_IP/g" \
            #     -e "s/IP2/$ORG2_IP/g" \
            #     -e "s/IP3/$ORG3_IP/g" \
            #     -e "s/IP4/$ORG4_IP/g" \
            #     -e "s/IP5/$ORG5_IP/g" \
            #     -e "s/IP6/$ORG6_IP/g" \
            #     -e "s/MAIN_IP/$MAIN_IP/g" \
            #     -e "s/KAFKA_PORT/$KAFKA_PORT/g" \
            #     -e "s/ZOOKEEPER_PORT/$ZOOKEEPER_PORT/g" \
            #     ${template_file} > ${result_file}
            sed -e "s/ORG/$ORG/g" \
                -e "s/DOMAIN/$DOMAIN/g" \
                -e "s/HOST_ID/$HOST_ID/g" \
                -e "s/MAIN_IP/$MAIN_IP/g" \
                -e "s/KAFKA_PORT/$KAFKA_PORT/g" \
                -e "s/ZOOKEEPER_PORT/$ZOOKEEPER_PORT/g" \
                ${template_file} > ${result_file}
        fi
    fi



    # TODO: prometheus 설정
    # prometheus/prometheus.yaml 파일 생성 -> ORG1만 실행
    # if [ "${ORG}" == "org1"} ]; then
    #     template_file=$TEMPLATES_DOCKER_COMPOSE_FOLDER/prometheus/prometheus-template.yaml
    #     result_file=$GENERATED_DOCKER_COMPOSE_FOLDER/prometheus/prometheus.yaml
    #     sed -e "s/DOMAIN/$DOMAIN/g" \
    #         -e "s/ORG1/$ORG1/g" \
    #         -e "s/ORG2/$ORG2/g" \
    #         -e "s/ORG3/$ORG3/g" \
    #         -e "s/ORG4/$ORG4/g" \
    #         -e "s/ORG5/$ORG5/g" \
    #         -e "s/ORG6/$ORG6/g" \
    #         -e "s/IP1/$ORG1_IP/g" \
    #         -e "s/IP2/$ORG2_IP/g" \
    #         -e "s/IP3/$ORG3_IP/g" \
    #         -e "s/IP4/$ORG4_IP/g" \
    #         -e "s/IP5/$ORG5_IP/g" \
    #         -e "s/IP6/$ORG6_IP/g" \
    #         ${template_file} > ${result_file}
    # fi

    # docker-compose-monitoring.yaml 파일 생성		
    # cp $TEMPLATES_DOCKER_COMPOSE_FOLDER/docker-compose-monitoring.yaml $GENERATED_DOCKER_COMPOSE_FOLDER/docker-compose-monitoring.yaml

}

# API 등을 실행하기 위해 필요한 config 파일 생성
function createConfigJsonFiles() {
    echo "Create config.json files"
    # REST API 실행을 위한 network-config.json 세팅
    ## network-config.json에서 orderer 설정 세팅
    networkConfigOut=`sed -e "s/MAIN_ORG/$ORG/g" \
             -e "s/MAIN_IP/$MAIN_IP/g" \
             -e "s/DOMAIN/$DOMAIN/g" \
             -e "s/^\s*\/\/.*$//g" \
                $TEMPLATES_ARTIFACTS_FOLDER/network-config-template.json`
    networkConfigPlaceholder=",}}"

    # # IPFS 실행을 위한 ipfs-config.json 세팅
    # ipfsConfigOut=`echo {}}`
    # ipfsConfigPlaceholder="}}"

    count=1
    while [ ${count} -le ${ORG_CNT} ]; do
        org=org${count}
        IP=IP${count}

        ## network-config.json에서 org 설정 세팅
        networkConfigSnippet=`sed -e "s/ORG/$org/g" \
                     -e "s/DOMAIN/$DOMAIN/g" \
                     -e "s/IP/${!IP}/g" \
                     $TEMPLATES_ARTIFACTS_FOLDER/network-config-orgsnippet.json`
        networkConfigOut="${networkConfigOut//$networkConfigPlaceholder/,$networkConfigSnippet}"

        # ## ipfs-config.json에서 org 설정 세팅
        # ipfsConfigSnippet=`sed -e "s/ORG/$org/g" \
        #              -e "s/IP/${!IP}/g" \
        #              -e "s/CHANNEL_NAME/$CHANNEL_NAME/g" \
        #              -e "s/CHAINCODE_NAME/haccp_ipfs/g" \
        #              $TEMPLATES_ARTIFACTS_FOLDER/ipfs-config-orgsnippet.json`
        # ipfsConfigOut="${ipfsConfigOut//$ipfsConfigPlaceholder/,$ipfsConfigSnippet}"

        count=$(( ${count}+1 ))
    done
    
    # network-config.json 파일 생성
    networkConfig="${networkConfigOut//$networkConfigPlaceholder/\}\}}"
    echo ${networkConfig} > $GENERATED_ARTIFACTS_FOLDER/network-config.json

    # # ipfs-config.json 파일 생성
    # ipfsConfig="${ipfsConfigOut//,$ipfsConfigPlaceholder/\}}"
    # echo ${ipfsConfig} > $GENERATED_ARTIFACTS_FOLDER/ipfs-config.json

    # # Blockchanin Explorer 연결을 위한 config 파일 생성
    # explorer_placeholder=",}}"
    # explorer_out="${out//$explorer_placeholder/\}}"
    # echo ${explorer_out} > ../blockchain-explorer/config.temp.json
    # sed -e "s/crypto-config/..\/network\/artifacts\/crypto-config/g" ../blockchain-explorer/config.temp.json > ../blockchain-explorer/config.json
    # sed -e "s/MAIN_IP/$MAIN_IP/g" ../blockchain-explorer/config-extra.json >> ../blockchain-explorer/config.json

}

printSettingValue
if [ "${ORDERER_TYPE}" == "solo" ]; then
    copyBasicFilesForSolo
    # ORG="org1" DOMAIN="example.com" ORG_CNT=2 ./honeybee_hl_byfn.sh up -o solo -s couchdb -n
else
    if [ "${ORG}" == "org1" ]; then
        createCryptoConfigYamlFiles
        createConfigtxYamlFiles
    fi
    createHostsFiles
    createDockerComposeYamlFiles
    createConfigJsonFiles
fi