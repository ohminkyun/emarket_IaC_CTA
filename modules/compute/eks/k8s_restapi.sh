#!/bin/bash

########################################################################################################
#                         Required Environment Variables                                               #
#                                                                                                      #
# CLUSTER_ID="eks_dev_km_svc_dev_kr"                                                                   #
# API_SERVER="https://292E2EEDD5398E2BF196263E30B16ADB.gr7.ap-northeast-2.eks.amazonaws.com"           #
# API_VERSION="apis/rbac.authorization.k8s.io/v1"                                                      #
# KIND="ClusterRoleBinding"                                                                            #
# NAMESPACE="default"                                                                                  #
# NAME="cluster-view"                                                                                  #
# MANIFEST=""                                                                                          #
# ########################################################################################################
# CLUSTER_ID="eks_dev_km_svc_dev_kr" 
# API_SERVER="https://292E2EEDD5398E2BF196263E30B16ADB.gr7.ap-northeast-2.eks.amazonaws.com"

# SAMPLE-#1
# API_VERSION="apis/rbac.authorization.k8s.io/v1"
# KIND="ClusterRoleBinding"
# NAMESPACE="default"
# NAME="cluster-view"
# MANIFEST="
# apiVersion: rbac.authorization.k8s.io/v1
# kind: ClusterRoleBinding
# metadata:
#   name: cluster-view
# roleRef:
#   apiGroup: rbac.authorization.k8s.io
#   kind: ClusterRole
#   name: view
# subjects:
# - apiGroup: rbac.authorization.k8s.io
#   kind: Group
#   name: user:viewers
# "

# SAMPLE-#2
# API_VERSION="apis/apps/v1"
# KIND="Deployment"
# NAMESPACE="kube-system"
# NAME="coredns"
# MANIFEST='[ {"op": "add", "path": "/spec/template/metadata/annotations", "value": {"eks.amazonaws.com/compute-type": "ec2"}} ]'
# MANIFEST='[ {"op": "remove", "path": "/spec/template/metadata/annotations/eks.amazonaws.com~1compute-type"} ]'

__ERR_MSG() {
    local strMsg=$1
    echo "[ERROR] $strMsg - $(echo $RESP | jq '"Code: " + (.code|tostring) + ", Reason: " + .reason + ", HTTP_CODE: " + (.http_code|tostring)')"
}

__OK_MSG() {
    local strMsg=$1
    echo "[OK] $strMsg"
}

__REST_REQ() {
    local strMethod=$1; local strTarget=$2; local strData=$3; local strHeader=$4; strHeader=${strHeader:="Content-type: application/yaml"}

    RESP=$(curl -s -X $strMethod -w "\n{\n  \"http_code\": %{http_code}\n}\n" --insecure -H "$strHeader" -H "Authorization: Bearer $TOKEN" --data "$strData" $API_SERVER/$strTarget | jq -s add )
    # echo "curl -s -X $strMethod -w "\n{\n  \"http_code\": %{http_code}\n}\n" --insecure -H "$strHeader" -H "Authorization: Bearer $TOKEN" --data "$strData" $API_SERVER/$strTarget"
    if [[ $(echo $RESP | jq '.status') == "Failure" || ! $(echo $RESP | jq '.http_code') =~ 2[0-9]{2} ]]; then
        __ERR_MSG "[__REST_REQ] $strMethod request to $strTarget Failed"
        return 0
    fi
    
    return 1
}

_NAMESPACED() {
    # Return URI global variable
    
    __REST_REQ "GET" "$API_VERSION"
    if [[ $? -eq 0 ]]; then
        #__ERR_MSG "[_NAMESPACED] $API_VERSION Failed"
        return $?
    fi    
    
    
    local bNamespaced=$(echo $RESP | jq -r --arg KEY $KIND '.resources[] | select( .kind == $KEY and (.name | contains("/") | not ) ) | .namespaced')
    local strKinds=$(echo $RESP | jq -r --arg KEY $KIND '.resources[] | select( .kind == $KEY and (.name | contains("/") | not ) ) | .name')
    
    if [[ -z $bNamespaced ]]; then
        __ERR_MSG "Namespaced for $KIND not found, please check manifest"
        return 0
    fi
    
    if [[ $bNamespaced == "true" ]]; then URI="$API_VERSION/namespaces/$NAMESPACE/$strKinds"; else URI="$API_VERSION/$strKinds"; fi

    return 1
}

_EXIST() {
    # Return CNT global variable
    local strUri=$1
    
    __REST_REQ "GET" "$strUri"
    if [[ $? -eq 0 ]]; then
        #_ERR_MSG "[_EXIST] Resource($strUri) Failed"
        return $?
    fi
    
    CNT=$(echo $RESP | jq --arg KEY $NAME '[.items[] | select( .metadata.name == $KEY)] | length')
    
    return 1
}

CREATE() {
    # Delete first if resource exists except for Namespace
    DELETE; local retVal=$?
    # Create resource
    if [[ $retVal -eq 2 ]]; then
        __OK_MSG "[CREATE] Namespace($NAME) Already exists, Skip"
        return 1
    elif [[ $retVal -eq 1 ]]; then
        __REST_REQ "POST" "$URI" "$MANIFEST"
        if [[ $? -eq 0 ]]; then
            __ERR_MSG "[CREATE] Resource($URI/$NAME) Create Failed"
            return $?
        fi
        __OK_MSG "[CREATE] Resource($URI/$NAME) Created"
        return 1
    fi
    
    return $retVal
}

DELETE() {
    _NAMESPACED
    if [[ $? -eq 0 ]]; then
        return $?
    fi
    
    _EXIST $URI
    if [[ $CNT -gt 0 ]]; then
        if [[ $KIND == "Namespace" ]]; then
            __OK_MSG "[DELETE] Namespace($NAME) won't be deleted (Recommanded)"
            return 2
        else
            # Delete Resource except for namespace
            __REST_REQ "DELETE" "$URI/$NAME"
            if [[ $? -eq 0 ]]; then
                return $?
            fi
        fi
        __OK_MSG "[DELETE] Resource($URI/$NAME) Deleted"
        return 1
    elif [[ $CNT -eq 0 ]]; then
        # 해당 resource가 존재하지 않는 경우,
        #echo "Resource($URI/$NAME) Not found $CNT $URI"
        return 1
    fi

    return 0
}

PATCH() {
    _NAMESPACED
    if [[ $? -eq 0 ]]; then
        return $?
    fi

    # 자원 존재여부 확인
    _EXIST $URI
    if [[ $? -eq 0 ]]; then
        return $?
    fi
    
    # CHECK operation 
    if [[ $CNT -gt 0 ]]; then
        __REST_REQ "GET" "$URI/$NAME"
        if [[ $? -eq 0 ]]; then
            #_ERR_MSG "[PATCH] Resource($strUri/$NAME) GET Failed"
            return $?
        fi
        
        #local nPathsCnt=$(echo $MANIFEST | jq -r '[.[] | select(.op | test("remove|replace")) | .path] | length')
        local strPaths=$(echo $MANIFEST | jq -r '[.[] | select( .op | test("remove|replace|add")) | .op + "=" + ( .path | split("/")[1:] | join(".") | "." + . ) | gsub("~1"; "/")] | join(" ")')

        local nErrCnt=0
        for value in $strPaths; do
            local op=$(echo $value | awk -F'=' '{print $1}'); local path=$(echo $value | awk -F'=' '{print $2}')
            local nMatched=$(echo $RESP | jq -r --arg KEY $path '[ paths  | map(strings = ".\(.)" | numbers = ".\(.)") | join("") | select( . | contains($KEY) )] | length')
            if [[ $op != "add" && $nMatched -eq 0 ]]; then
                if [[ $op == "remove" ]]; then
                    __OK_MSG "[PATCH] Resource($URI/$NAME) Path($path) already removed"
                    continue
                fi
            fi
            
            __REST_REQ "PATCH" "$URI/$NAME" "$MANIFEST" "Content-type: application/json-patch+json"
            if [[ $? -eq 0 ]]; then
                #_ERR_MSG "[PATCH] Resource($strUri/$NAME) $path Patch Failed"
                nErrCnt=$((nErrCnt + 1))
                continue
            fi
        done
    fi
    
    if [[ $nErrCnt -gt 0 ]]; then
        __ERR_MSG "[PATCH] Resource($URI/$NAME) NOT Patched (Error count: $nErrCnt)"
        return 0
    fi
    
    __OK_MSG "[PATCH] Resource($URI/$NAME) Patched"
    return 1
}


# Appl. check
if [[ $(command -v aws curl jq | wc -l) -lt 3 ]]; then
        echo "[ERROR] You have to install awscli, curl and jq exiting..."
        exit 1
fi

TOKEN=$(aws eks get-token --cluster-name $CLUSTER_ID | jq -r '.status.token')

$1
if [[ $? -eq 0 ]]; then
    exit 1
fi
exit 0