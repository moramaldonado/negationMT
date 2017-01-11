# -*- coding: utf-8 -*-
"""
Created on Fri Apr 17 18:40:03 2015

@author: moramaldonado
"""


import json
import os
#import matplotlib.pyplot as plt
import os
import csv
import pickle
import time
import math
import pygame

def _decode_list(data):
    rv = []
    for item in data:
        if isinstance(item, unicode):
            item = item.encode('utf-8')
        elif isinstance(item, list):
            item = _decode_list(item)
        elif isinstance(item, dict):
            item = _decode_dict(item)
        rv.append(item)
    return rv

def _decode_dict(data):
    rv = {}
    for key, value in data.iteritems():
        if isinstance(key, unicode):
            key = key.encode('utf-8')
        if isinstance(value, unicode):
            value = value.encode('utf-8')
        elif isinstance(value, list):
            value = _decode_list(value)
        elif isinstance(value, dict):
            value = _decode_dict(value)
        rv[key] = value
    return rv

def joining_data(rootDir):

    all_trials=[]
    names = []

    for dirName, subdirList, fileList in os.walk(rootDir):
        print('Found directory: %s' % dirName)
        for fname in fileList:
            if fname.endswith('.json'):
                names.append(fname)
                #subjects.append(fname.replace('.json',''))

                os.chdir(dirName)
                with open(str(fname)) as f:
                    print('\t%s' % fname)
                    for line in f:
                        all_trials.append(json.loads(line, object_hook=_decode_dict))

                #print('\t%s' % fname) 

    return all_trials,names


def exporting_data(path,all_trials, experiment, info):
    os.chdir(path)
    name = 'Data_'+experiment+'.csv'
    info_name = 'Information_'+experiment+'.csv'
    
    with open(info_name, 'w') as m:
        writer = csv.writer(m)
        writer.writerow( ('Subject', 'Experiment', 'File', 'Gender', 'Age', 'Total.time', 'Points', 'Clicker',
                         'Handeness','Language','Mobile','Normalized_button','Portrait','Strategy','Touch',
                          'User-agent','Window') )        

        for j in range(len(info)):
            if info[j]['experiment'] == experiment:
                writer.writerow((info[j]['subject'],  info[j]['experiment'], info[j]['file'], info[j]['gender'],info[j]['age'],info[j]['total_time'],info[j]['points'], info[j]['clicker'][0], 
                                info[j]['handedness'], info[j]['language'], info[j]['mobile'], info[j]['normalized_button_size'], info[j]['portrait'], info[j]['strategy'], info[j]['touch'],info[j]['userAgent'], info[j]['windowWidth']))
        
     
    with open(name, 'w') as f:
        
        writer = csv.writer(f)
        writer.writerow( ('Subject', 'Sentence_Type', 'Block', 'Timing','Target',
                          'Expected_response','Response','Accuracy','RT','MaxDeviation','MaxDeviation.Time','MaxDeviation.Time.Norm',
                          'MaxDeviationBorder','MaxDeviationBorder.Time','MaxDeviationBorder.Time.Norm',
                          'MaxRatio','MaxLogRatio','MaxRatio.Time','MaxRatio.Time.Norm','MaxDifference','MaxDifference.Time','MaxDifference.Time.Norm',
                          'AccPeak','AccPeak.Time','AccPeak.Time.Norm', 'Int.Ratio.AccPeak', 'Int.LogRatio.AccPeak','Int.Difference.AccPeak','Int.X.AccPeak','Local.Maxima.Acc','Len.Local.Maxima','Delay', 'Ratio.Acc') )

        for i in range(len(all_trials)):
            if info[i]['experiment'] == experiment:
                for t in range(len(all_trials[i])):
                    #print i,t
                    writer.writerow((str(i), all_trials[i][t]['type'], all_trials[i][t]['block'], all_trials[i][t]['timing'],
                                     all_trials[i][t]['target'], all_trials[i][t]['expected_response'],
                                        all_trials[i][t]['value'], all_trials[i][t]['accuracy'], all_trials[i][t]['RT'], all_trials[i][t]['maxDeviation'][0], all_trials[i][t]['maxDeviation'][1],all_trials[i][t]['maxDeviation'][2], all_trials[i][t]['maxDeviationBorder'][0], all_trials[i][t]['maxDeviationBorder'][1],all_trials[i][t]['maxDeviationBorder'][2], all_trials[i][t]['max_ratio'][0],all_trials[i][t]['max_ratio_log'][0],all_trials[i][t]['max_ratio'][1],all_trials[i][t]['max_ratio'][2],all_trials[i][t]['max_difference'][0],all_trials[i][t]['max_difference'][1],all_trials[i][t]['max_difference'][2], all_trials[i][t]['max_smooth_acceleration'][0],all_trials[i][t]['max_smooth_acceleration'][1],all_trials[i][t]['max_smooth_acceleration'][2], all_trials[i][t]['integral_ratio_on_max_smooth_acceleration'],all_trials[i][t]['integral_ratio_log_on_max_smooth_acceleration'],all_trials[i][t]['integral_difference_on_max_smooth_acceleration'],all_trials[i][t]['integral_X_on_max_smooth_acceleration'],all_trials[i][t]['local_maxima'],len(all_trials[i][t]['local_maxima']),all_trials[i][t]['delay'],all_trials[i][t]['ratio_log_in_max_smooth_acceleration']))
                                        
  
    f.close()
    m.close()


def points_per_trial(all_trials):
    points_per_trial = []
    for s in range(len(all_trials)):
        points = []
        for t in range(len(all_trials[s])-2):
            points.append(len(all_trials[s][t]['mouse_log']))
        mean = sum(points)/len(points)
        points_per_trial.append([mean,max(points),min(points)])
    return points_per_trial


def information(all_trials,names,points_per_trial):
    total_time = []
    info = []
    for i in range(len(all_trials)):
        m = all_trials[i][-2]['timestamp'] - all_trials[i][0]['timestamp']
        m = float(m /1000)
        m = float(m/60)
        total_time.append(m)
    
        all_trials[i][-2]['subject'] = i
        all_trials[i][-2]['experiment'] = all_trials[i][0]['data']['design']['exp']
        all_trials[i][-2]['strategy'] = all_trials[i][-1]['strategy']
        all_trials[i][-2]['total_time'] = m
        all_trials[i][-2]['file'] = names[i]
        all_trials[i][-2]['points']= points_per_trial[i]
        del all_trials[i][-1]
        info.append(all_trials[i][-1])
        del all_trials[i][-1]

    return info, total_time

def convert_time(all_trials):
    for s in range(len(all_trials)):
        for t in range(len(all_trials[s])):
            for p in range(len(all_trials[s][t]['mouse_log'])):
                raw_time = all_trials[s][t]['mouse_log'][p][2] - all_trials[s][t]['data']['start_track']
                all_trials[s][t]['mouse_log'][p].append(raw_time)
    
    return all_trials         

def organization_trials(all_trials):
    for i in range(len(all_trials)):
        acc = 0
        for t in range(len(all_trials[i])):
            all_trials[i][t]['subject'] = i
            all_trials[i][t]['RT'] = all_trials[i][t]['data']['end_track'] - all_trials[i][t]['data']['start_track']
            all_trials[i][t]['delaySTART'] = all_trials[i][t]['data']['start_track'] - all_trials[i][t]['data']['start_time']
            all_trials[i][t]['experiment'] = all_trials[i][t]['data']['design']['exp']
            all_trials[i][t]['block'] = all_trials[i][t]['data']['design']['block']
            all_trials[i][t]['timing'] = all_trials[i][t]['data']['design']['timing']
            all_trials[i][t]['target'] = all_trials[i][t]['data']['design']['target']
            all_trials[i][t]['type'] = all_trials[i][t]['data']['item']['type']
    #        if all_trials[i][t]['data']['item']['vignette']['target'] == 'filler':
    #            all_trials[i][t]['type'] = 'filler'

            if all_trials[i][t]['data']['item']['type'] == 'practice':
                all_trials[i][t]['expected_response'] = 'null'
            else: 
                all_trials[i][t]['expected_response'] = str(all_trials[i][t]['target'])
         
            # if t == 0:
            #     all_trials[i][t]['previous.condition'] = '0'
            # else:
            #
            #     all_trials[i][t]['previous.condition'] = all_trials[i][t-1]['condition']
            #     if all_trials[i][t-1]['type'] == 'controlp' or all_trials[i][t-1]['type'] == 'controln':
            #         all_trials[i][t]['previous.condition'] = 'control'
            #     if all_trials[i][t-1]['type'] == 'starget' and all_trials[i][t-1]['expected_response'] == 'False':
            #         all_trials[i][t]['previous.condition'] = 'filler'
            #

            if all_trials[i][t]['expected_response'] == all_trials[i][t]['value']:
                all_trials[i][t]['accuracy'] = 1
            else:
                all_trials[i][t]['accuracy'] = 0
            #
            # if t == 0:
            #
            #     all_trials[i][t]['previous.accuracy'] = 'null'
            # else:
            #     all_trials[i][t]['previous.accuracy'] = all_trials[i][t-1]['accuracy']

            acc = acc + all_trials[i][t]['accuracy']

        print 'subject:'+str(i) +',correct:'+ str(acc)+',experiment:'+all_trials[i][1]['experiment']

    return all_trials

def delay(all_trials):
    for i in range(len(all_trials)):
        for t in range(len(all_trials[i])):
            if len(all_trials[i][t]['mouse_log']) > 1:
                all_trials[i][t]['delay'] = all_trials[i][t]['mouse_log'][1][3]
            else: 
                all_trials[i][t]['delay'] = 'NA'
    return all_trials
