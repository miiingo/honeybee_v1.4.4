#!/bin/bash
#
# Copyright IBM Corp All Rights Reserved
#
# SPDX-License-Identifier: Apache-2.0
#

# 이 스크립트는 Hyperledger 패브릭 네트워크의 샘플 종단 간(end-to-end) 실행을 조정합니다.
#
# end-to-end 검증은 두 개의 peer를 유지 관리하는 두 개의 Org와
# "solo" ordering ​​서비스로 구성된 샘플 패브릭 네트워크를 제공합니다.
#
# This verification은 디지털 서명 유효성 검사 및 액세스 제어 기능을 갖춘
# 트랜잭션 네트워크를 만드는 데 필요한 두 가지 기본 도구를 사용합니다. :
#
# * cryptogen - 네트워크의 다양한 구성 요소를 식별하고 인증하는 데 사용되는 x509 인증서를 생성합니다.
# * configtxgen - orderer 부트 스트랩 및 채널 생성을 위해 필수 구성 아티팩트를 생성합니다.
#
# 각 도구는 네트워크의 토폴로지(cryptogen)와 다양한 구성 작업(configtxgen)에 대한
# 인증서의 위치를 ​​지정하는 구성 yaml 파일을 사용합니다.
# 도구가 성공적으로 실행되면 네트워크를 시작할 수 있습니다.
# 도구 및 네트워크 구조에 대한 자세한 내용은이 문서 뒷부분에 나와 있습니다.
# 우선, 계속 진행하도록 합니다...

# $PWD/../bin을 PATH에 prepending하여 올바른 바이너리를 선택하도록합니다.
# 원하는 경우 도구의 설치된 버전을 해결하기 위해 주석 처리 될 수 있습니다.
export PATH=${PWD}/../bin:${PWD}:$PATH
export FABRIC_CFG_PATH=${PWD}/artifacts
export VERBOSE=false

# 기본값; 이 스크립트를 실행하기 전에 이 변수를 내 보냅니다.;
export HONEYBEE_PROJECT_HOME=$PWD
export GENERATED_ARTIFACTS_FOLDER=$HONEYBEE_PROJECT_HOME/artifacts
export GENERATED_DOCKER_COMPOSE_FOLDER=$HONEYBEE_PROJECT_HOME/docker-compose
export GENERATED_SCRIPTS_FOLDER=$HONEYBEE_PROJECT_HOME/scripts

# : ${CORP:="honeybee"}

# 필수 파라매터 항목: kafka 기준
# : ${ORDERER_TYPE="kafka"}
: ${ORG:="org1"}
# : ${DOMAIN:="honeybee.com"}
# : ${ORDERER_CNT:="3"}
# : ${ORG_CNT:="3"}
# : ${PEER_CNT:="2"}
# : ${BATCH_TIMEOUT="2s"}
# : ${MAX_MESSAGE_COUNT="10"}


[[ -d $GENERATED_ARTIFACTS_FOLDER ]] || mkdir -p $GENERATED_ARTIFACTS_FOLDER/channel-artifacts
[[ -d $GENERATED_DOCKER_COMPOSE_FOLDER ]] || mkdir -p $GENERATED_DOCKER_COMPOSE_FOLDER/base
[[ -d $GENERATED_SCRIPTS_FOLDER ]] || mkdir -p $GENERATED_SCRIPTS_FOLDER

GID=$(id -g)



# 사용법 메시지 출력
function printHelp() {
  echo "Usage: "
  echo "  honeybee_hl_byfn.sh <mode> [-c <channel name>] [-t <timeout>] [-d <delay>] [-f <docker-compose-file>] [-s <dbtype>] [-l <language>] [-o <consensus-type>] [-i <imagetag>] [-a] [-n] [-v]"
  echo "    <mode> - one of 'up', 'down', 'restart', 'generate' or 'upgrade'"
  echo "      - 'up' - bring up the network with docker-compose up"
  echo "      - 'down' - clear the network with docker-compose down"
  echo "      - 'restart' - restart the network"
  echo "      - 'generate' - generate required certificates and genesis block"
  echo "      - 'upgrade'  - upgrade the network from version 1.3.x to 1.4.0"
  echo "    -c <channel name> - channel name to use (defaults to \"mychannel\")"
  echo "    -t <timeout> - CLI timeout duration in seconds (defaults to 10)"
  echo "    -d <delay> - delay duration in seconds (defaults to 3)"
  echo "    -f <docker-compose-file> - specify which docker-compose file use (defaults to docker-compose-cli.yaml)"
  echo "    -s <dbtype> - the database backend to use: goleveldb (default) or couchdb"
  echo "    -l <language> - the chaincode language: golang (default) or node"
  echo "    -o <consensus-type> - the consensus-type of the ordering service: solo (default), kafka, or etcdraft"
  echo "    -i <imagetag> - the tag to be used to launch the network (defaults to \"latest\")"
  echo "    -a - launch certificate authorities (no certificate authorities are launched by default)"
  echo "    -n - do not deploy chaincode (abstore chaincode is deployed by default)"
  echo "    -v - verbose mode"
  echo "  honeybee_hl_byfn.sh -h (print this message)"
  echo
  echo "Typically, one would first generate the required certificates and "
  echo "genesis block, then bring up the network. e.g.:"
  echo
  echo "	honeybee_hl_byfn.sh generate -c mychannel"
  echo "	honeybee_hl_byfn.sh up -c mychannel -s couchdb"
  echo "        honeybee_hl_byfn.sh up -c mychannel -s couchdb -i 1.4.0"
  echo "	honeybee_hl_byfn.sh up -l node"
  echo "	honeybee_hl_byfn.sh down -c mychannel"
  echo "        honeybee_hl_byfn.sh upgrade -c mychannel"
  echo
  echo "Taking all defaults:"
  echo "	honeybee_hl_byfn.sh generate"
  echo "	honeybee_hl_byfn.sh up"
  echo "	honeybee_hl_byfn.sh down"
}

# 계속할 것인지 묻는 메시지가 표시됩니다.
function askProceed() {
  read -p "Continue? [Y/n] " ans
  case "$ans" in
  y | Y | "")
    echo "proceeding ..."
    ;;
  n | N)
    echo "exiting..."
    exit 1
    ;;
  *)
    echo "invalid response"
    askProceed
    ;;
  esac
}

# CONTAINER_IDS 구하기 및 제거
# TODO 이 옵션을 선택하고 싶을 수도 있습니다. 다른 컨테이너를 지울 수 있습니다.
function clearContainers() {
  CONTAINER_IDS=$(docker ps -a | awk '($2 ~ /dev-peer.*/) {print $1}')

  if [ -z "$CONTAINER_IDS" -o "$CONTAINER_IDS" == " " ]; then
    echo "---- No containers available for deletion ----"
  else
    docker rm -f $CONTAINER_IDS
  fi
}

# 이 설정의 일부로 생성된 이미지 삭제
# 구체적으로 다음 이미지가 종종 남아 있습니다.:
# TODO 생성된 이미지 명명 패턴 목록
function removeUnwantedImages() {
  DOCKER_IMAGE_IDS=$(docker images | awk '($1 ~ /dev-peer.*/) {print $3}')
  if [ -z "$DOCKER_IMAGE_IDS" -o "$DOCKER_IMAGE_IDS" == " " ]; then
    echo "---- No images available for deletion ----"
  else
    docker rmi -f $DOCKER_IMAGE_IDS
  fi
}

# 이 first-network 릴리스에서 작동하지 않는 것으로 알려진 패브릭 버전
BLACKLISTED_VERSIONS="^1\.0\. ^1\.1\.0-preview ^1\.1\.0-alpha"

# 적절한 버전의 패브릭 바이너리/이미지를 사용할 수 있는지 확인하기 위해 몇 가지 기본적인 온전성 검사를 수행하십시오.
# 앞으로는 이동 또는 기타 항목의 추가에 대한 존재 여부 검사가 추가 될 수 있습니다.
function checkPrereqs() {
  # Note, configtxlator는 구성 파일을 필요로하지 않기 때문에 외부에서 configtxlator를 확인하고
  # configtxlator가 docker에서 '개발 버전'을 반환하도록하는 FAB-8551로 인해 docker 이미지에서 피어링합니다.
  LOCAL_VERSION=$(configtxlator version | sed -ne 's/ Version: //p')
  DOCKER_IMAGE_VERSION=$(docker run --rm hyperledger/fabric-tools:$IMAGETAG peer version | sed -ne 's/ Version: //p' | head -1)

  echo "LOCAL_VERSION=$LOCAL_VERSION"
  echo "DOCKER_IMAGE_VERSION=$DOCKER_IMAGE_VERSION"

  if [ "$LOCAL_VERSION" != "$DOCKER_IMAGE_VERSION" ]; then
    echo "=================== WARNING ==================="
    echo "  Local fabric binaries and docker images are  "
    echo "  out of  sync. This may cause problems.       "
    echo "==============================================="
  fi

  for UNSUPPORTED_VERSION in $BLACKLISTED_VERSIONS; do
    echo "$LOCAL_VERSION" | grep -q $UNSUPPORTED_VERSION
    if [ $? -eq 0 ]; then
      echo "ERROR! Local Fabric binary version of $LOCAL_VERSION does not match this newer version of BYFN and is unsupported. Either move to a later version of Fabric or checkout an earlier version of fabric-samples."
      exit 1
    fi

    echo "$DOCKER_IMAGE_VERSION" | grep -q $UNSUPPORTED_VERSION
    if [ $? -eq 0 ]; then
      echo "ERROR! Fabric Docker image version of $DOCKER_IMAGE_VERSION does not match this newer version of BYFN and is unsupported. Either move to a later version of Fabric or checkout an earlier version of fabric-samples."
      exit 1
    fi
  done
}

function printSettingValue () {

  echo "========================================== Setting Value ==========================================="
  echo "ORG NAME : '${ORG}'"
  echo "DOMAIN : '${DOMAIN}'"
  echo "CONSENSUS_TYPE : '${CONSENSUS_TYPE}'"
  echo "ORDERER_CNT : '${ORDERER_CNT}'"
  echo "ORG_CNT : '${ORG_CNT}'"
  echo "PEER_CNT : '${PEER_CNT}'"
  echo "BATCH_TIMEOUT : '${BATCH_TIMEOUT}'"
  echo "MAX_MESSAGE_COUNT : '${MAX_MESSAGE_COUNT}'"
  echo
  echo "Use Honeybee-Project home: $HONEYBEE_PROJECT_HOME"
  echo "Use target artifact folder: $GENERATED_ARTIFACTS_FOLDER"
  echo "Use target docker-compose folder: $GENERATED_DOCKER_COMPOSE_FOLDER"
  echo "Use target scripts folder: $GENERATED_SCRIPTS_FOLDER"
  echo "===================================================================================================="
}


# 필요한 인증서와 생성 블록을 생성하고 네트워크를 시작하십시오.
function networkUp() {
  printSettingValue
  checkPrereqs

  export ORDERER_TYPE=$CONSENSUS_TYPE
  if [ "${CONSENSUS_TYPE}" == "solo" ]; then
    # solo 모드용 변수 세팅
    export DOMAIN="example.com"
    export ORDERER_CNT="1"
    export ORG_CNT="2"
    export PEER_CNT="2"
    export BATCH_TIMEOUT="2s"
    export MAX_MESSAGE_COUNT="10"
  elif [ "${CONSENSUS_TYPE}" == "kafka" ]; then
    # kafka 모드용 변수 세팅
    export ORG=$ORG
    export DOMAIN=$DOMAIN
    export ORDERER_CNT=$ORDERER_CNT
    export ORG_CNT=$ORG_CNT
    export PEER_CNT=$PEER_CNT
    export BATCH_TIMEOUT=$BATCH_TIMEOUT
    export MAX_MESSAGE_COUNT=$MAX_MESSAGE_COUNT
  fi

  # 환경에 맞는 설정 파일들을 생성하는 honeybee_hl_byfn_set.sh 스크립트 실행
  ./honeybee_hl_byfn_set.sh
  if [ $? -ne 0 ]; then
    echo "ERROR !!!! Run honeybee_hl_byfn_set.sh failed"
    exit 1
  fi

  # generate artifacts if they don't exist
  # if [ ! -d "crypto-config" ]; then
  #   generateCerts
  #   replacePrivateKey
  #   generateChannelArtifacts
  # fi

  if [ "$MODE" != "restart" ]; then
    if [ ${ORG} == 'org1' ]; then
      generateCerts
      generateChannelArtifacts
    fi
  fi

  COMPOSE_FILES="-f ${COMPOSE_FILE} -f ${COMPOSE_FILE_API}"
  if [ "${CERTIFICATE_AUTHORITIES}" == "true" ]; then
    COMPOSE_FILES="${COMPOSE_FILES} -f ${COMPOSE_FILE_CA}"
    if [ "${CONSENSUS_TYPE}" == "solo" ]; then
      export BYFN_CA1_PRIVATE_KEY=$(cd $GENERATED_ARTIFACTS_FOLDER/crypto-config/peerOrganizations/org1.${DOMAIN}/ca && ls *_sk)
      export BYFN_CA2_PRIVATE_KEY=$(cd $GENERATED_ARTIFACTS_FOLDER/crypto-config/peerOrganizations/org2.${DOMAIN}/ca && ls *_sk)
    else
      export CA_PRIVATE_KEY=$(cd $GENERATED_ARTIFACTS_FOLDER/crypto-config/peerOrganizations/${ORG}.${DOMAIN}/ca && ls *_sk)
    fi
  fi
  if [ "${CONSENSUS_TYPE}" == "kafka" ]; then
    COMPOSE_FILES="${COMPOSE_FILES} -f ${COMPOSE_FILE_KAFKA}"
  elif [ "${CONSENSUS_TYPE}" == "etcdraft" ]; then
    COMPOSE_FILES="${COMPOSE_FILES} -f ${COMPOSE_FILE_RAFT2}"
  fi
  if [ "${IF_COUCHDB}" == "couchdb" ]; then
    COMPOSE_FILES="${COMPOSE_FILES} -f ${COMPOSE_FILE_COUCH}"
  fi
  IMAGE_TAG=$IMAGETAG COMPOSE_PROJECT_NAME=$COMPOSE_PROJECT_NAME docker-compose ${COMPOSE_FILES} up -d 2>&1
  docker ps -a
  if [ $? -ne 0 ]; then
    echo "ERROR !!!! Unable to start network"
    exit 1
  fi

  if [ "$CONSENSUS_TYPE" == "kafka" ]; then
    sleep 1
    echo "Sleeping 10s to allow $CONSENSUS_TYPE cluster to complete booting"
    sleep 9
  fi

  if [ "$CONSENSUS_TYPE" == "etcdraft" ]; then
    sleep 1
    echo "Sleeping 15s to allow $CONSENSUS_TYPE cluster to complete booting"
    sleep 14
  fi

  # now run the end to end script
  docker exec cli scripts/script.sh $CHANNEL_NAME $CLI_DELAY $LANGUAGE $CLI_TIMEOUT $VERBOSE $NO_CHAINCODE
  if [ $? -ne 0 ]; then
    echo "ERROR !!!! Test failed"
    exit 1
  fi
}

# Upgrade the network components which are at version 1.3.x to 1.4.x
# Stop the orderer and peers, backup the ledger for orderer and peers, cleanup chaincode containers and images
# and relaunch the orderer and peers with latest tag
# function upgradeNetwork() {
#   if [[ "$IMAGETAG" == *"1.4"* ]] || [[ $IMAGETAG == "latest" ]]; then
#     docker inspect -f '{{.Config.Volumes}}' orderer.example.com | grep -q '/var/hyperledger/production/orderer'
#     if [ $? -ne 0 ]; then
#       echo "ERROR !!!! This network does not appear to start with fabric-samples >= v1.3.x?"
#       exit 1
#     fi

#     LEDGERS_BACKUP=./ledgers-backup

#     # create ledger-backup directory
#     mkdir -p $LEDGERS_BACKUP

#     export IMAGE_TAG=$IMAGETAG
#     COMPOSE_FILES="-f ${COMPOSE_FILE}"
#     if [ "${CERTIFICATE_AUTHORITIES}" == "true" ]; then
#       COMPOSE_FILES="${COMPOSE_FILES} -f ${COMPOSE_FILE_CA}"
#       if [ "${CONSENSUS_TYPE}" == "solo" ]; then
#         export BYFN_CA1_PRIVATE_KEY=$(cd $GENERATED_ARTIFACTS_FOLDER/crypto-config/peerOrganizations/org1.${DOMAIN}/ca && ls *_sk)
#         export BYFN_CA2_PRIVATE_KEY=$(cd $GENERATED_ARTIFACTS_FOLDER/crypto-config/peerOrganizations/org2.${DOMAIN}/ca && ls *_sk)
#       else
#         export CA_PRIVATE_KEY=$(cd $GENERATED_ARTIFACTS_FOLDER/crypto-config/peerOrganizations/${ORG}.${DOMAIN}/ca && ls *_sk)
#       fi
#     fi
#     if [ "${CONSENSUS_TYPE}" == "kafka" ]; then
#       COMPOSE_FILES="${COMPOSE_FILES} -f ${COMPOSE_FILE_KAFKA}"
#     elif [ "${CONSENSUS_TYPE}" == "etcdraft" ]; then
#       COMPOSE_FILES="${COMPOSE_FILES} -f ${COMPOSE_FILE_RAFT2}"
#     fi
#     if [ "${IF_COUCHDB}" == "couchdb" ]; then
#       COMPOSE_FILES="${COMPOSE_FILES} -f ${COMPOSE_FILE_COUCH}"
#     fi

#     # removing the cli container
#     docker-compose $COMPOSE_FILES stop cli
#     docker-compose $COMPOSE_FILES up -d --no-deps cli

#     echo "Upgrading orderer"
#     docker-compose $COMPOSE_FILES stop orderer.example.com
#     docker cp -a orderer.example.com:/var/hyperledger/production/orderer $LEDGERS_BACKUP/orderer.example.com
#     docker-compose $COMPOSE_FILES up -d --no-deps orderer.example.com

#     for PEER in peer0.org1.example.com peer1.org1.example.com peer0.org2.example.com peer1.org2.example.com; do
#       echo "Upgrading peer $PEER"

#       # Stop the peer and backup its ledger
#       docker-compose $COMPOSE_FILES stop $PEER
#       docker cp -a $PEER:/var/hyperledger/production $LEDGERS_BACKUP/$PEER/

#       # Remove any old containers and images for this peer
#       CC_CONTAINERS=$(docker ps | grep dev-$PEER | awk '{print $1}')
#       if [ -n "$CC_CONTAINERS" ]; then
#         docker rm -f $CC_CONTAINERS
#       fi
#       CC_IMAGES=$(docker images | grep dev-$PEER | awk '{print $1}')
#       if [ -n "$CC_IMAGES" ]; then
#         docker rmi -f $CC_IMAGES
#       fi

#       # Start the peer again
#       docker-compose $COMPOSE_FILES up -d --no-deps $PEER
#     done

#     docker exec cli scripts/upgrade_to_v14.sh $CHANNEL_NAME $CLI_DELAY $LANGUAGE $CLI_TIMEOUT $VERBOSE
#     if [ $? -ne 0 ]; then
#       echo "ERROR !!!! Test failed"
#       exit 1
#     fi
#   else
#     echo "ERROR !!!! Pass the v1.4.x image tag"
#   fi
# }

# 실행중인 네트워크 중단
function networkDown() {

  setComposeFiles

  # stop org3 containers also in addition to org1 and org2, in case we were running sample to add org3
  # stop kafka and zookeeper containers in case we're running with kafka consensus-type
  REST_IMAGETAG=$REST_IMAGETAG IMAGE_TAG=$IMAGETAG COMPOSE_PROJECT_NAME=$COMPOSE_PROJECT_NAME docker-compose ${compose_files} down --volumes --remove-orphans
  # --volumes : 볼륨 제거
  # --remove-orphans : compose 파일에 정의되지 않은 서비스 컨테이너 제거

  # 생성된 아티팩트를 제거하지 마십시오. 원장은 항상 제거됩니다.
  if [ "$MODE" != "restart" ]; then
    # 네트워크를 종료하고 볼륨을 삭제하십시오.
    #모든 원장 백업을 삭제
    docker run -v $PWD:/tmp/first-network --rm hyperledger/fabric-tools:$IMAGETAG rm -Rf /tmp/first-network/ledgers-backup
    #컨테이너 정리
    clearContainers
    #이미지 정리
    removeUnwantedImages
    # ORG1일 경우에만 orderer 블록 및 기타 채널 구성 트랜잭션 및 인증서 제거
    if [ "$ORG" == "org1" ]; then
      rm -rf *artifacts/
      # 스크립트 파일 정리
      rm -rf scripts/*.sh
    fi
    # template에 맞게 사용자 정의된 docker-compose.yaml 파일을 제거
    rm -rf docker-compose/*.yaml docker-compose/base/*.yaml
    rm -rf artifacts/crypto-config
  fi
}

# 중지할 docker-compose.yaml 파일 정의
function setComposeFiles () {
  compose_files=""

  if [ -e ${COMPOSE_FILE} ]; then
      echo "stopping docker instances from $COMPOSE_FILE"
      compose_files="$compose_files -f $COMPOSE_FILE"
  fi
  if [ -e ${COMPOSE_FILE_COUCH} ]; then
      echo "stopping docker instances from $COMPOSE_FILE_COUCH"
      compose_files="$compose_files -f $COMPOSE_FILE_COUCH"
  fi
  if [ -e ${COMPOSE_FILE_KAFKA} ]; then
      echo "stopping docker instances from $COMPOSE_FILE_KAFKA"
      compose_files="$compose_files -f $COMPOSE_FILE_KAFKA"
  fi
  if [ -e ${COMPOSE_FILE_RAFT2} ]; then
      echo "stopping docker instances from $COMPOSE_FILE_RAFT2"
      compose_files="$compose_files -f $COMPOSE_FILE_RAFT2"
  fi
  if [ -e ${COMPOSE_FILE_CA} ]; then
      echo "stopping docker instances from $COMPOSE_FILE_CA"
      compose_files="$compose_files -f $COMPOSE_FILE_CA"
  fi
  if [ -e ${COMPOSE_FILE_ORG3} ]; then
      echo "stopping docker instances from $COMPOSE_FILE_ORG3"
      compose_files="$compose_files -f $COMPOSE_FILE_ORG3"
  fi
  if [ -e ${COMPOSE_FILE_API} ]; then
      echo "stopping docker instances from $COMPOSE_FILE_API"
      compose_files="$compose_files -f $COMPOSE_FILE_API"
  fi
}


# docker-compose-e2e-template.yaml을 사용하여 cryptogen 도구로 생성된 개인 키 파일 이름으로 상수를 대체하고
# 이 구성과 관련된 docker-compose.yaml을 출력하십시오.
# function replacePrivateKey() {
#   # MacOSX에서 sed는 널 확장자를 가진 -i 플래그를 지원하지 않습니다.
#   # 우리는 백업의 확장을 위해 't'를 사용하고 함수의 끝에서 그것을 삭제할 것입니다.
#   ARCH=$(uname -s | grep Darwin)
#   if [ "$ARCH" == "Darwin" ]; then
#     OPTS="-it"
#   else
#     OPTS="-i"
#   fi

#   # 개인 키를 추가하도록 수정될 파일로 template을 복사하십시오.
#   cp docker-compose-e2e-template.yaml docker-compose-e2e.yaml

#   # 다음 단계에서는 템플릿의 내용을 두 CA에 대한 개인 키 파일 이름의 실제 값으로 바꿉니다.
#   CURRENT_DIR=$PWD
#   cd crypto-config/peerOrganizations/org1.example.com/ca/
#   PRIV_KEY=$(ls *_sk)
#   cd "$CURRENT_DIR"
#   sed $OPTS "s/CA1_PRIVATE_KEY/${PRIV_KEY}/g" docker-compose-e2e.yaml
#   cd crypto-config/peerOrganizations/org2.example.com/ca/
#   PRIV_KEY=$(ls *_sk)
#   cd "$CURRENT_DIR"
#   sed $OPTS "s/CA2_PRIVATE_KEY/${PRIV_KEY}/g" docker-compose-e2e.yaml
#   # MacOSX 인 경우 docker-compose 파일의 임시 백업을 제거하십시오.
#   if [ "$ARCH" == "Darwin" ]; then
#     rm docker-compose-e2e.yamlt
#   fi
# }

# cryptogen 도구를 사용하여 다양한 네트워크 엔터티에 대한 암호 자료 (x509 certs)를 생성합니다.
# 인증서는 공통 PKI 구현을 기반으로하며 여기에서는 공통 trust 앵커에 도달하여 유효성을 검사합니다.
#
# Cryptogen은 네트워크 토폴로지를 포함하고있는 ``crypto-config.yaml`` 파일을 사용하며
# 조직과 해당 조직에 속한 구성 요소 모두에 대한 인증서 라이브러리를 생성할 수 있습니다.
# 각 조직은 특정 구성 요소(peer 및 orderer)를 해당 조직에 바인딩하는 고유한 루트 인증서(``ca-cert``)를 제공합니다.
# Fabric 내의 트랜잭션과 통신은 엔티티의 개인 키(``keystore``)에 의해 서명된
# 다음 공개 키(``signcerts``)를 통해 검증됩니다.
# 이 파일에는 "count" 변수가 있습니다.
# 우리는 이를 사용하여 조직 당 피어의 수를 지정합니다.; 우리의 경우 Org 당 두 명의 peer가 있습니다.
# 이 템플릿의 나머지 부분은 매우 자명(self-explanatory)합니다.
#
# 이 도구를 실행하면 certs는 ``crypto-config``라는 폴더에 보관됩니다.

# cryptogen 도구를 사용하여 Org certs 생성
function generateCerts() {
  which cryptogen
  if [ "$?" -ne 0 ]; then
    echo "cryptogen tool not found. exiting"
    exit 1
  fi
  echo
  echo "##########################################################"
  echo "##### Generate certificates using cryptogen tool #########"
  echo "##########################################################"

  if [ -d "crypto-config" ]; then
    rm -Rf crypto-config
  fi
  set -x
  # cryptogen generate --config=./crypto-config.yaml
  cryptogen generate --output=$GENERATED_ARTIFACTS_FOLDER/crypto-config --config=$GENERATED_ARTIFACTS_FOLDER/"crypto-config.yaml"
  res=$?
  set +x
  if [ $res -ne 0 ]; then
    echo "Failed to generate certificates..."
    exit 1
  fi
  echo
}

# The `configtxgen tool is used to create four artifacts: orderer **bootstrap
# block**, fabric **channel configuration transaction**, and two **anchor
# peer transactions** - one for each Peer Org.
#
# The orderer block is the genesis block for the ordering service, and the
# channel transaction file is broadcast to the orderer at channel creation
# time.  The anchor peer transactions, as the name might suggest, specify each
# Org's anchor peer on this channel.
#
# Configtxgen consumes a file - ``configtx.yaml`` - that contains the definitions
# for the sample network. There are three members - one Orderer Org (``OrdererOrg``)
# and two Peer Orgs (``Org1`` & ``Org2``) each managing and maintaining two peer nodes.
# This file also specifies a consortium - ``SampleConsortium`` - consisting of our
# two Peer Orgs.  Pay specific attention to the "Profiles" section at the top of
# this file.  You will notice that we have two unique headers. One for the orderer genesis
# block - ``HoneybeeOrdererGenesis`` - and one for our channel - ``HoneybeeChannel``.
# These headers are important, as we will pass them in as arguments when we create
# our artifacts.  This file also contains two additional specifications that are worth
# noting.  Firstly, we specify the anchor peers for each Peer Org
# (``peer0.org1.example.com`` & ``peer0.org2.example.com``).  Secondly, we point to
# the location of the MSP directory for each member, in turn allowing us to store the
# root certificates for each Org in the orderer genesis block.  This is a critical
# concept. Now any network entity communicating with the ordering service can have
# its digital signature verified.
#
# This function will generate the crypto material and our four configuration
# artifacts, and subsequently output these files into the ``channel-artifacts``
# folder.
#
# If you receive the following warning, it can be safely ignored:
#
# [bccsp] GetDefault -> WARN 001 Before using BCCSP, please call InitFactories(). Falling back to bootBCCSP.
#
# You can ignore the logs regarding intermediate certs, we are not using them in
# this crypto implementation.

# Generate orderer genesis block, channel configuration transaction and
# anchor peer update transactions
function generateChannelArtifacts() {
  which configtxgen
  if [ "$?" -ne 0 ]; then
    echo "configtxgen tool not found. exiting"
    exit 1
  fi

  echo "##########################################################"
  echo "#########  Generating Orderer Genesis block ##############"
  echo "##########################################################"
  # Note: For some unknown reason (at least for now) the block file can't be
  # named orderer.genesis.block or the orderer will fail to launch!
  echo "CONSENSUS_TYPE="$CONSENSUS_TYPE
  set -x
  if [ "$CONSENSUS_TYPE" == "solo" ]; then
    configtxgen -profile HoneybeeOrdererGenesis -channelID $SYS_CHANNEL -outputBlock $GENERATED_ARTIFACTS_FOLDER/channel-artifacts/honeybee-orderer-genesis.block
  elif [ "$CONSENSUS_TYPE" == "kafka" ]; then
    configtxgen -profile SampleDevModeKafka -channelID $SYS_CHANNEL -outputBlock $GENERATED_ARTIFACTS_FOLDER/channel-artifacts/honeybee-orderer-genesis.block
  elif [ "$CONSENSUS_TYPE" == "etcdraft" ]; then
    configtxgen -profile SampleMultiNodeEtcdRaft -channelID $SYS_CHANNEL -outputBlock $GENERATED_ARTIFACTS_FOLDER/channel-artifacts/honeybee-orderer-genesis.block
  else
    set +x
    echo "unrecognized CONSESUS_TYPE='$CONSENSUS_TYPE'. exiting"
    exit 1
  fi
  res=$?
  set +x
  if [ $res -ne 0 ]; then
    echo "Failed to generate orderer genesis block..."
    exit 1
  fi
  echo
  echo "#################################################################"
  echo "### Generating channel configuration transaction 'channel.tx' ###"
  echo "#################################################################"
  set -x
  configtxgen -profile HoneybeeChannel -outputCreateChannelTx $GENERATED_ARTIFACTS_FOLDER/channel-artifacts/channel.tx -channelID $CHANNEL_NAME
  res=$?
  set +x
  if [ $res -ne 0 ]; then
    echo "Failed to generate channel configuration transaction..."
    exit 1
  fi

  count=1
  while [ ${count} -le ${ORG_CNT} ]; do
    if [ "$CONSENSUS_TYPE" == "solo" ]; then
      ORG_MSP="Org${count}MSP"
    else
      ORG_MSP="org${count}MSP"
    fi
    echo
    echo "#################################################################"
    echo "#######    Generating anchor peer update for ${ORG_MSP}   ##########"
    echo "#################################################################"
    set -x
    configtxgen -profile HoneybeeChannel -outputAnchorPeersUpdate $GENERATED_ARTIFACTS_FOLDER/channel-artifacts/${ORG_MSP}anchors.tx -channelID $CHANNEL_NAME -asOrg ${ORG_MSP}
    res=$?
    set +x
    if [ $res -ne 0 ]; then
      echo "Failed to generate anchor peer update for ${ORG_MSP}..."
      exit 1
    fi
    count=$(( ${count}+1 ))
  done
  # echo
  # echo "#################################################################"
  # echo "#######    Generating anchor peer update for Org1MSP   ##########"
  # echo "#################################################################"
  # set -x
  # configtxgen -profile HoneybeeChannel -outputAnchorPeersUpdate ./channel-artifacts/Org1MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org1MSP
  # res=$?
  # set +x
  # if [ $res -ne 0 ]; then
  #   echo "Failed to generate anchor peer update for Org1MSP..."
  #   exit 1
  # fi

  # echo
  # echo "#################################################################"
  # echo "#######    Generating anchor peer update for Org2MSP   ##########"
  # echo "#################################################################"
  # set -x
  # configtxgen -profile HoneybeeChannel -outputAnchorPeersUpdate \
  #   ./channel-artifacts/Org2MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org2MSP
  # res=$?
  # set +x
  # if [ $res -ne 0 ]; then
  #   echo "Failed to generate anchor peer update for Org2MSP..."
  #   exit 1
  # fi
  echo
}

# 플랫폼에 맞는 올바른 native 바이너리를 선택하는 데 사용할 OS 및 아키텍처 문자열을 얻습니다.
# e.g., darwin-amd64 or linux-amd64
OS_ARCH=$(echo "$(uname -s | tr '[:upper:]' '[:lower:]' | sed 's/mingw64_nt.*/windows/')-$(uname -m | sed 's/x86_64/amd64/g')" | awk '{print tolower($0)}')
# timeout duration - CLI가 다른 컨테이너의 응답을 기다려야하는 기간.
CLI_TIMEOUT=10
# 명령 간 지연 기본값
CLI_DELAY=3
# 시스템 채널 이름의 기본값
SYS_CHANNEL="byfn-sys-channel"
# 채널 이름의 기본값
CHANNEL_NAME="mychannel"
# 컴포즈 프로젝트 이름의 기본값
COMPOSE_PROJECT_NAME="honeybee"
# use this as the default docker-compose yaml definition
COMPOSE_FILE=$GENERATED_DOCKER_COMPOSE_FOLDER/docker-compose-cli.yaml
#
COMPOSE_FILE_COUCH=$GENERATED_DOCKER_COMPOSE_FOLDER/docker-compose-couch.yaml
# REST API
COMPOSE_FILE_API=$GENERATED_DOCKER_COMPOSE_FOLDER/docker-compose-api.yaml
# org3 docker compose file
COMPOSE_FILE_ORG3=$GENERATED_DOCKER_COMPOSE_FOLDER/docker-compose-org3.yaml
# kafka and zookeeper compose file
COMPOSE_FILE_KAFKA=$GENERATED_DOCKER_COMPOSE_FOLDER/docker-compose-kafka.yaml
# two additional etcd/raft orderers
COMPOSE_FILE_RAFT2=$GENERATED_DOCKER_COMPOSE_FOLDER/docker-compose-etcdraft2.yaml
# certificate authorities compose file
COMPOSE_FILE_CA=$GENERATED_DOCKER_COMPOSE_FOLDER/docker-compose-ca.yaml
#
# chaincode의 기본 언어(golang)
LANGUAGE=golang
# fabric 이미지 태그
IMAGETAG="1.4.4"
# consensus type 기본값
CONSENSUS_TYPE="solo"

# REST API 이미지 태그
REST_IMAGETAG="0.11.7"
# CA 사용 여부 기본값
# CA_USE="false"
CA_USE="true"
# COUCHDB 사용 여부 기본값
IF_COUCHDB="couchdb"
# MODE 기본값
MODE_TYPE="ope"



# Parse commandline args
if [ "$1" = "-m" ]; then # supports old usage, muscle memory is powerful!
  shift
fi
MODE=$1
shift
# Determine whether starting, stopping, restarting, generating or upgrading
if [ "$MODE" == "up" ]; then
  EXPMODE="Starting"
elif [ "$MODE" == "down" ]; then
  EXPMODE="Stopping"
elif [ "$MODE" == "restart" ]; then
  EXPMODE="Restarting"
elif [ "$MODE" == "generate" ]; then
  EXPMODE="Generating certs and genesis block"
elif [ "$MODE" == "upgrade" ]; then
  EXPMODE="Upgrading the network"
else
  printHelp
  exit 1
fi

while getopts "h?c:t:d:f:s:l:i:o:anv" opt; do
  case "$opt" in
  h | \?)
    printHelp
    exit 0
    ;;
  c)
    CHANNEL_NAME=$OPTARG
    ;;
  t)
    CLI_TIMEOUT=$OPTARG
    ;;
  d)
    CLI_DELAY=$OPTARG
    ;;
  f)
    COMPOSE_FILE=$OPTARG
    ;;
  s)
    IF_COUCHDB=$OPTARG
    ;;
  l)
    LANGUAGE=$OPTARG
    ;;
  i)
    IMAGETAG=$(go env GOARCH)"-"$OPTARG
    ;;
  o)
    CONSENSUS_TYPE=$OPTARG
    ;;
  a)
    CERTIFICATE_AUTHORITIES=true
    ;;
  n)
    NO_CHAINCODE=true
    ;;
  v)
    VERBOSE=true
    ;;
  esac
done


# Announce what was requested

if [ "${IF_COUCHDB}" == "couchdb" ]; then
  echo
  echo "${EXPMODE} for channel '${CHANNEL_NAME}' with CLI timeout of '${CLI_TIMEOUT}' seconds and CLI delay of '${CLI_DELAY}' seconds and using database '${IF_COUCHDB}'"
else
  echo "${EXPMODE} for channel '${CHANNEL_NAME}' with CLI timeout of '${CLI_TIMEOUT}' seconds and CLI delay of '${CLI_DELAY}' seconds"
fi
# ask for confirmation to proceed
askProceed

#Create the network using docker compose
if [ "${MODE}" == "up" ]; then
  networkUp
elif [ "${MODE}" == "down" ]; then ## Clear the network
  networkDown
elif [ "${MODE}" == "generate" ]; then ## Generate Artifacts
  generateCerts
  replacePrivateKey
  generateChannelArtifacts
elif [ "${MODE}" == "restart" ]; then ## Restart the network
  networkDown
  networkUp
elif [ "${MODE}" == "upgrade" ]; then ## Upgrade the network from version 1.2.x to 1.3.x
  upgradeNetwork
else
  printHelp
  exit 1
fi
