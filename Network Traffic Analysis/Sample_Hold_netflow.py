'''
if pck not tracked:
    add w/prob P
else:
        update # pkts
        update # bytes

P = L/#packets

key -> value
(ip.src,ip.dst,ip.p,tcp.sport,tcp.dport) -> [num_packets,num_bytes]

'''
import dpkt
import socket
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import sys
import operator
import random

fd = open("peering.pcap", "rb")
pcap = dpkt.pcap.Reader(fd)

sample_hold_dict = {}
num_packets = 0
prob = 10000/40000000
error_count = 0

print(prob)




#---------------------------START PCAP LOOP--------------------------
for ts, data in pcap:
    #-----------------break for testing-----------------------------
    
    num_packets += 1
    if num_packets % 10000000 == 0:
        print('10 M sampled')

    '''
    if num_packets > 1000000:
        break
    '''
    #----------------end testing break-------------------------------

    ip = dpkt.ip.IP(data)
    ip_src = socket.inet_ntoa(ip.src)
    ip_dst = socket.inet_ntoa(ip.dst)
    protocol = ip.p
    size = ip.len
    #--------------TCP ports----------------
    if protocol == 6:
        tcp = ip.data
        try:
            d_port = tcp.dport
            s_port = tcp.sport
        except:
            error_count += 1
            #print('tcp pkt error: ' , tcp , ' not valid')
            d_port = 0
            s_port = 0
    
    #--------------UDP ports----------------
    elif protocol == 17:
        udp = ip.data
        try:
            d_port = udp.dport
            s_port = udp.sport
        except:
            error_count += 1
            #print('udp pkt error: ' , udp , ' not valid')
            d_port = 0
            s_port = 0


    #-----------check if key is in the dict-------------------
    key = (ip_src,ip_dst,protocol,s_port,d_port)
    valid_key = True
    if key[3] == 0 and key[4] == 0:
        #print('invalid key, ignoring')
        valid_key = False
    #print(key)
    if key in sample_hold_dict:
        value = sample_hold_dict.get(key)
        ptk_count = value[0]
        byte_count = value[1]
        ptk_count += 1
        byte_count = byte_count + size
        sample_hold_dict[key] = [ptk_count,byte_count]

    #--------if not in dict, add with prob P----------
    elif valid_key == True:
        rand_num = random.random()
        #print(rand_num)
        if rand_num <= prob:
            sample_hold_dict[key] = [1,size]
            #print('new sample added')

        

#--------------------------------END PCAP LOOP---------------------------
print('END PCAP LOOP')
print('number of packets: ' , num_packets)
print('number of errors: ' , error_count)
total_flow = len(sample_hold_dict)
print('number of flows sampled: ' ,total_flow)
#print(sample_hold_dict)
sorted_max_bytes = sorted(sample_hold_dict.keys(), key = lambda k: sample_hold_dict[k][1] ,reverse = True)[:5]

sorted_sample_hold = sorted(sample_hold_dict.items(),key=operator.itemgetter(1),reverse = True)

print('heavy hitters by number of packets')
for i in range(5):
    print('key : ' , sorted_sample_hold[i])

print('heavy hitters by number of bytes')
for i in sorted_max_bytes:
    val = sample_hold_dict.get(i)
    print(i , ',' , val)

#---------ITERATE THROUGH ALL FLOW RECORDS------------------------
unique_src_ip = []
unique_dest_ip = []
total_bytes = 0
tcp_bytes = 0
min_bytes = 10000000
max_bytes = 0
min_packets = 1000000
max_packets = 0
total_packets = 0

for i in range(total_flow):
    flow = sorted_sample_hold[i][0]
    data = sorted_sample_hold[i][1]
    ip_src = flow[0]
    ip_dst = flow[1]
    protocol = flow[2]
    #---unique src/dst ip addrs-----------
    if ip_src not in unique_src_ip:
        unique_src_ip.append(ip_src)
    if ip_dst not in unique_dest_ip:
        unique_dest_ip.append(ip_dst)
    #---fraction of tcp traffic-----------
    total_bytes = total_bytes + data[1]
    if protocol == 6:
        tcp_bytes = tcp_bytes + data[1]
    #---min/max packets/bytes--------
    total_packets = total_packets + data[0]
    if min_packets > data[0]:
        min_packets = data[0]
    if max_packets < data[0]:
        max_packets = data[0]
    if min_bytes > data[1]:
        min_bytes = data[1]
    if max_bytes < data[1]:
        max_bytes = data[1]



    
print('unquie source IP: ' , len(unique_src_ip))
print('unquie dest IP: ' , len(unique_dest_ip))
print('total bytes: ' , total_bytes)
print('tcp bytes: ' , tcp_bytes)
print('tcp/total bytes: ', tcp_bytes/total_bytes)
print('min packets: ' , min_packets , ' max packets: ' , max_packets , ' avg packets: ' , total_packets/total_flow)
print('min bytes: ' , min_bytes , ' max bytes: ' , max_bytes , ' avg bytes: ' , total_bytes/total_flow)
#  random.randint(0,99)  use for random generation

fd.close()
