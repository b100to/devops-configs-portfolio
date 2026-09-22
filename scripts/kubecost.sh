#kubecost 사용할 때 사용하는 스크립트

#!/bin/bash

#  if [ -z "$1" ]; then
#echo "Error: Missing environment parameter"
#  exit 1
#  fi

  multiply_by_2() {
  input=$1
  value=$(echo $input | grep -o -E '[0-9]+(\.[0-9]+)?')
  unit=$(echo $input | grep -o -E '[a-zA-Z]+')
  new_value=$(echo "$value * 2" | bc)
  echo "${new_value}${unit}"
}

#  environment=$1
  cnt=0
  nscnt=0
  multiplier=100
  kubecost_address='https://kubecost.dev.acme.example/model'


  # Local Test
  # path_list=("../../../helm-chart/boutique/values/$environment/resources.yaml" "../../../helm-chart/msa/values/$environment/resources.yaml" "../../../helm-chart/example/values/$environment/resources.yaml")

  # Github Action
  path_list=("./resources.yaml")
  namespace_list=("mall")

  echo "  ======================= Kubecost Resource RightSizing Recommendation !! =======================  "
  for namespace in ${namespace_list[@]}; do
  response=$(curl -G -d 'algorithmCPU=max' -d 'targetCPUUtilization=0.8' -d 'targetRAMUtilization=0.8' -d 'window=7d' --data-urlencode "filter=namespace:\"$namespace\"" ${kubecost_address}/savings/requestSizingV2)
  echo $response > $namespace.yaml
  cat $namespace.yaml
  container_list=`yq eval '.Recommendations[].containerName' $namespace.yaml`
  cnt=0
  for container in ${container_list[@]}; do
  controllerKind=`yq eval ".Recommendations[$cnt].controllerKind" $namespace.yaml`
  latestKnownRequest=`yq eval ".Recommendations[$cnt].latestKnownRequest" $namespace.yaml`
  cpu=`yq eval ".Recommendations[$cnt].latestKnownRequest.cpu" $namespace.yaml`
  memory=`yq eval ".Recommendations[$cnt].latestKnownRequest.memory" $namespace.yaml`
  recommendedRequest=`yq eval ".Recommendations[$cnt].recommendedRequest" $namespace.yaml`
  currentEfficiency=`yq eval ".Recommendations[$cnt].currentEfficiency.total" $namespace.yaml`
  currentEfficiency=$(printf "%.4f" $currentEfficiency)

echo "Kind: $controllerKind Container: $container, LatestKnownRequest: $latestKnownRequest, RecommendedRequest: $recommendedRequest, CurrentEfficiency: $(echo "$currentEfficiency*$multiplier" | bc)"
  echo -e "\n"

  if [[ $cpu != "null" ]] && [[ $memory != "null" ]]; then
  recommend_cpu=`yq eval ".Recommendations[$cnt].recommendedRequest.cpu" $namespace.yaml`
  recommend_memory=`yq eval ".Recommendations[$cnt].recommendedRequest.memory" $namespace.yaml`
  new_cpu=$(multiply_by_2 $recommend_cpu)
  new_memory=$(multiply_by_2 $recommend_memory)

  yq eval -i ".${container}.resources.requests.cpu = \"$new_cpu\"" ${path_list[$nscnt]}
  yq eval -i ".${container}.resources.requests.memory = \"$new_memory\"" ${path_list[$nscnt]}
  yq eval -i ".${container}.resources.limits.cpu = \"$new_cpu\"" ${path_list[$nscnt]}
  yq eval -i ".${container}.resources.limits.memory = \"$new_memory\"" ${path_list[$nscnt]}
  fi
  cnt=$((cnt+1))
  done
  nscnt=$((nscnt+1))
  rm $namespace.yaml
  done