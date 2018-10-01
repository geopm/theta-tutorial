#!/bin/bash

if [ $# -ne 0 ]; then
   REQUIRED_NUM_NODES=$1
else
   REQUIRED_NUM_NODES=0
fi

# Try to read a MSR.  Print the hostname if it fails.
CHECK_RDMSR=check_rdmsr.sh
echo '#!/bin/bash' > $CHECK_RDMSR
echo "geopmread POWER_PACKAGE_TDP package 0 >& /dev/null || hostname | sed -e 's/nid[0]*//'" >> $CHECK_RDMSR
echo 'true' >> $CHECK_RDMSR
chmod u+x $CHECK_RDMSR
BAD_NODES=$(aprun -n $COBALT_JOBSIZE -N1 -q ./$CHECK_RDMSR | tr '\n' ' ' | sed 's/\>/,/g;s/ //g;s/,$//')
echo -n $BAD_NODES
rm -f $CHECK_RDMSR
if [ -z "$BAD_NODES" ]; then
    NUM_BAD_NODES=0
else
    NUM_BAD_NODES=$(echo $BAD_NODES | sed 's|[^,]||g' | wc -c)
fi
if [ $REQUIRED_NUM_NODES -gt $(($COBALT_JOBSIZE - $NUM_BAD_NODES)) ]; then
    >&2 echo "Error: number of msr-safe enabled nodes is less than number of nodes required!"
    >&2 echo "Warning: msr-safe failure detected on the following nodes: $BAD_NODES"
    exit 1
fi
