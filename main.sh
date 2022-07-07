#!/bin/bash
### To fetch the Current component details and show on grafana through Mysql ###
cd /var/lib/jenkins/Staging/component_status/
pager_key="bbf5198940af4c2dac756facecd7069a"


trap 'pager' ERR EXIT
pager() { 
	pd-send -k $pager_key -t trigger -d "Scripts Component failed. Please check line no $LINENO on path /var/lib/jenkins/Staging/component_status"
}

cat $PWD/access_config | awk '{print $1,$2,$3,$4}' | awk '!NF || !seen[$0]++' > $PWD/tmp
> $PWD/all_component_status.csv
> $PWD/${client}/${client}_current_conf
> $PWD/${client}/${client}_actual_conf

while IFS=' ' read pem user hostname client
do
 
	if ! scp -i /var/lib/jenkins/ssh/${pem} ${user}@${hostname}:/home/${user}/hdp/${client}/scripts/conf/list-of-apps /var/lib/jenkins/Staging/component_status/${client}
	then
		echo "unable to SCP to driver from : ${client}. Sending pager..."
		pager 
		continue
	else
		str=`cat $PWD/client_string | grep $client | awk '{print $NF}'`
		while read -r line ; do
      	
			if [[ `echo $line | awk '{print $4}'` == "${client}" ]]; then
				replace=`echo $line | awk '{print $5}'`
        			corrected=`echo $line | awk '{print $6}'`
				echo "***" $client $replace $corrected "***"
	
				sed -i "s/$replace/$corrected/g" "$PWD/${client}/list-of-apps"
			else
		      		continue
			fi
		
		done < access_config 

		cat $PWD/${client}/list-of-apps | sed /^$/d | grep -v '^\#' | sed 's/=/;/g' | awk -F';' '{print $1","$2","$3","$4","$7}' > "$PWD/${client}/${client}_current_conf"
		cat $PWD/config | grep "${str}" | awk '{print $0}' > "$PWD/${client}/${client}_actual_conf"		
		paste -d',' $PWD/${client}/${client}_actual_conf $PWD/${client}/${client}_current_conf | awk -F"," '{print $1","$2","$4","$3","$8","$5","$10}' >> $PWD/all_component_status.csv 

	fi

	if [ -s ${client}/${client}_current_conf -a -s ${client}/${client}_actual_conf ]; then 
		source $PWD/mysql_config
		if ! mysqlimport --fields-terminated-by=, --local -u ${user} -p${password} -P ${port}  --host=${hostname}  ${db_name} --delete $PWD/all_component_status.csv ; then
			echo "Found Issues while running MySQLImport ${client}. Sending pager..." 
			pager
			exit 0
		fi 
	else 
                        echo "Current Config or Sctual config file is blank so unable to update Mysql in Component Status script. Sending pager..."
			pager
			exit 0
	fi

done < $PWD/tmp

