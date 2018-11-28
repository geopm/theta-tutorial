#!/bin/bash

if [ $# -ne 0 ]; then
   NUM_REQUIRED_NODES=$1
else
   NUM_REQUIRED_NODES=0
fi

# Try to read a MSR.  Print the hostname if it fails.
CHECK_RDMSR=check_rdmsr.sh
echo '#!/bin/bash' > $CHECK_RDMSR
echo "geopmread POWER_PACKAGE_TDP package 0 >& /dev/null || hostname | sed -e 's/nid[0]*//'" >> $CHECK_RDMSR
echo 'true' >> $CHECK_RDMSR
chmod u+x $CHECK_RDMSR
BAD_NODES=$(aprun -n $COBALT_JOBSIZE -N1 -q ./$CHECK_RDMSR | tr '\n' ' ' | sed 's/\>/,/g;s/ //g;s/,$//')
rm -f $CHECK_RDMSR
if [ -z "$BAD_NODES" ]; then
    NUM_BAD_NODES=0
else
    NUM_BAD_NODES=$(echo $BAD_NODES | sed 's|[^,]||g' | wc -c)
    if [ $NUM_REQUIRED_NODES -gt $(($COBALT_JOBSIZE - $NUM_BAD_NODES)) ]; then
        >&2 echo "Error: number of msr-safe enabled nodes is less than number of nodes required!"
        >&2 echo "Warning: msr-safe failure detected on the following nodes: $BAD_NODES"
        exit 1
    else
        NUM_EXTRA_NODES=$(($COBALT_JOBSIZE - $NUM_BAD_NODES - $NUM_REQUIRED_NODES))
        if [ $NUM_EXTRA_NODES -gt 0 ]; then
            HOSTNAME=get_hostname.sh
            echo '#!/bin/bash' > $HOSTNAME
            echo "hostname | sed -e 's/nid[0]*//'" >> $HOSTNAME
            echo 'true' >> $HOSTNAME
            chmod u+x $HOSTNAME
            EXTRA_NODES=,$(aprun -E $BAD_NODES -n $(($COBALT_JOBSIZE - $NUM_BAD_NODES)) -N1 -q ./$HOSTNAME | \
                        sort | tail -n $NUM_EXTRA_NODES | tr '\n' ' ' | sed 's/\>/,/g;s/ //g;s/,$//')
            rm -f $HOSTNAME
        fi
        echo -n "-E $BAD_NODES$EXTRA_NODES"
    fi
fi

echo "NUM_BAD_NODES=$NUM_BAD_NODES" > exclude_nodes.log
echo "BAD_NODES=$BAD_NODES" >> exclude_nodes.log
echo "NUM_EXTRA=$NUM_EXTRA_NODES" >> exclude_nodes.log
echo "EXTRA_NODES=$EXTRA_NODES" >> exclude_nodes.log
