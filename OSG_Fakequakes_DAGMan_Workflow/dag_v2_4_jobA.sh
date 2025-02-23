#  	Thiss script executes Job A of DAGman_v2 
#
#       This includes preparing/making ruptures with MudPy if they're not already made and passed in. 
##

#### ----- Configure Parameters below ---------

#  Get the job name from submit file arguments. This is be the name of the directory initialized by
#  MudPy, and each job's output will be transferred out via the stash in the format $PROJNAME.tar.gz
PROJNAME=$1
HOMEPATH=$2

ncpus=$3                             # Number of CPUs. Set to 1 when first running make_ruptures=1     
run_name=$4                    # Run name (Note: this is not linked to the 'runnumber' mentioned above)

model_name=$5          # Velocity model
fault_name=$6              # Fault geometry
slab_name=$7                 # Slab 1.0 Ascii file (only used for 3D fault)
mesh_name=$8              # GMSH output file (only used for 3D fault)
distances_name=$9    # Name of distance matrix
utm_zone=${10}                        # Look here if unsure (https://en.wikipedia.org/wiki/Universal_Transverse_Mercator_coordinate_system#/media/File:Utm-zones.jpg)
scaling_law=${11}                       # Options: T for thrust, S for strike-slip, N for normal
dynamic_gflist=${12}                    # dynamic GFlist (True/False)
dist_threshold=${13}                 # #(degree) station to the closest subfault must be closer to this distance

#slip parameters
nrealizations=${14}                     # Number of fake ruptures to generate per magnitude bin. let Nrealizations % ncpus=0
target_mw=${15}               # Of what approximate magnitudes, parameters of numpy.arange()
max_slip=${16}                        # Maximum slip (m) allowed in the model

# Correlation function parameters
hurst=${17}                           # 0.4~0.7 is reasonable
ldip=${18}                           # Correlation length scaling, 'auto' uses  Mai & Beroza 2002, 
lstrike=${19}                        # MH2019 uses Melgar & Hayes 2019
lognormal=${20}			                # (True/False)
slip_standard_deviation=${21}
num_modes=${22}                       # Modes in K-L expantion (max#= munber of subfaults )
rake=${23}

# Rupture parameters
force_magnitude=${24}                   # Make the magnitudes EXACTLY the value in target_Mw (True/False)
force_area=${25}                        # Forces using the entire fault area defined by the .fault file as opposed to the scaling law (True/False)s
no_random=${26}                         # If true uses median length/width if false draws from prob. distribution (True/False)
time_epi=${27}        # Defines the hypocentral time
hypocenter=${28}        # Defines the specific hypocenter location if force_hypocenter=True
force_hypocenter=${29}                  # Forces hypocenter to occur at specified lcoationa s opposed to random (True/False)
mean_slip=${30}                      # Provide path to file name of .rupt to be used as mean slip pattern
center_subfault=${31}                # Integer value, if != None use that subfault as center for defining rupt area. If none then slected at random
use_hypo_fraction=${32}                 # If true use hypocenter PDF positions from Melgar & Hayes 2019, if false then selects at random   (True/False)

# Kinematic parameters
source_time_function=${33}         # options are 'triangle' or 'cosine' or 'dreger'
rise_time_depths=${34}             # Transition depths for rise time scaling
shear_wave_fraction=${35}             # Fraction of shear wave speed to use as mean rupture velocity
shear_wave_fraction_deep=${36}
shear_wave_fraction_shallow=${37}

# Station information (only used when syntehsizing waveforms)
gf_list=${38}
g_name=${39}

# Displacement and velocity waveform parameters and fk-parameters
nfft=${40}
dt=${41}
zeta=${42}
dk=${43}
pmin=${44}
pmax=${45}
kmax=${46}
custom_stf=${47}
rupture_list=${48}         # Don't change this (unless you know waht you're doing!)
max_slip_rule=${49}
slip_tol=${50}
stf_falloff_rate=${51}
rupture_name=${52}
hot_start=${53}
impulse=${54}				# (True/False)
epicenter=${55}



# New SSE params
moho_depth_in_km=${57}
hf_dt=${58}
duration=${59}
pwave=${60}
zero_phase=${61}
order=${62}
fcorner=${63}
inpolygon_fault=${64}
inpolygon_hypocenter=${65}
high_stress_depth=${66}
stress_parameter=${67}

########---------------- DO NOT CHANGE ANYTHING UNDER THIS (unless you know what you're doing)

##############################################################################################

set -e  # Have job exit if any command returns with non-zero exit status - aka failure

# get the name of the unique input for run
preparedinput=${56}


# Unpack the input files and check for what the user sent in
tar -xzf inputfiles.tar.gz
rm inputfiles.tar.gz

ruptsmade=0

# if ruptures.list exists then the user made and passsed in ruptures
#if [ -f ruptures.list ]; then 
#    ruptsmade=1
#fi


# Get the first line of the ruptures.list and if it's not equal to this message, this it's a rupture, and they were provided
firstline=$(head -n 1 ruptures.list)
norupsmessage="No ruptures were provided."
if [ ! "$firstline" == "$norupsmessage" ]; then
	ruptsmade=1
fi

# get the rupture runnumber from the run_name var and assign it to be used later
runnum=$(echo "$run_name" | tr -dc '0-9')

# make dir to contain the needed output to make waveforms in future jobs
mkdir preparedoutput$runnum

#echo "the mean_slip is: $mean_sleap"

echo "Pwave: $pwave"
echo "Moved input. Initing folder structure ..."

# if the ruptures and GFs/synths aren't both already made 
if [ "$ruptsmade" = "0" ]; then 

    # activate the python environment built in to this Singularity image
    cd /
    . quake3.6/bin/activate
    cd ~

    # Intialize a MudPy folder structure with the given $PROJNAME on the execute node 
    #python3 /MudPy/examples/fakequakes/planar/mudpy_single_exec_SSE.fq.py init -load_distances=0 -g_from_file=0 -ncpus=$ncpus -model_name=$model_name -fault_name=$fault_name -epicenter=$epicenter -slab_name=$slab_name -mesh_name=$mesh_name -distances_name=$distances_name -utm_zone=$utm_zone -scaling_law=$scaling_law -dynamic_gflist=$dynamic_gflist -dist_threshold=$dist_threshold -nrealizations=$nrealizations -max_slip=$max_slip -hurst=$hurst -ldip=$ldip -lstrike=$lstrike -lognormal=$lognormal -slip_standard_deviation=$slip_standard_deviation -num_modes=$num_modes -rake=$rake -force_magnitude=$force_magnitude -force_area=$force_area -no_random=$no_random -time_epi=$time_epi -hypocenter=$hypocenter -force_hypocenter=$force_hypocenter -mean_slip=$mean_slip -center_subfault=$center_subfault -use_hypo_fraction=$use_hypo_fraction -source_time_function=$source_time_function -rise_time_depths=$rise_time_depths -shear_wave_fraction=$shear_wave_fraction -gf_list=$gf_list -g_name=$g_name -nfft=$nfft -dt=$dt -dk=$dk -pmin=$pmin -pmax=$pmax -kmax=$kmax -custom_stf=$custom_stf -rupture_list=$rupture_list -target_mw=$target_mw -max_slip_rule=$max_slip_rule -slip_tol=$slip_tol -shear_wave_fraction_deep=$shear_wave_fraction_deep -shear_wave_fraction_shallow=$shear_wave_fraction_shallow -zeta=$zeta -stf_falloff_rate=$stf_falloff_rate -rupture_name=$rupture_name -hot_start=$hot_start -impulse=$impulse -home=$HOMEPATH -project_name=$PROJNAME -run_name=$run_name



    python3 /MudPy/examples/fakequakes/planar/mudpy_single_exec_SSE.fq.py init -load_distances=0 -g_from_file=0 -ncpus=$ncpus -model_name=$model_name -fault_name=$fault_name  -slab_name=$slab_name -mesh_name=$mesh_name -distances_name=$distances_name -utm_zone=$utm_zone -scaling_law=$scaling_law   -nrealizations=$nrealizations -max_slip=$max_slip -hurst=$hurst -ldip=$ldip -lstrike=$lstrike -lognormal=$lognormal -slip_standard_deviation=$slip_standard_deviation -num_modes=$num_modes -rake=$rake -force_magnitude=$force_magnitude -force_area=$force_area  -time_epi=$time_epi -force_hypocenter=$force_hypocenter  -use_hypo_fraction=$use_hypo_fraction -source_time_function=$source_time_function -rise_time_depths=$rise_time_depths -gf_list=$gf_list -g_name=$g_name -nfft=$nfft -dt=$dt -dk=$dk -pmin=$pmin -pmax=$pmax -kmax=$kmax -custom_stf=$custom_stf -rupture_list=$rupture_list -target_mw=$target_mw -max_slip_rule=$max_slip_rule  -stf_falloff_rate=$stf_falloff_rate  -hot_start=$hot_start -home=$HOMEPATH -project_name=$PROJNAME -run_name=$run_name -moho_depth_in_km=$moho_depth_in_km -hf_dt=$hf_dt -duration=$duration -pwave=$pwave -zero_phase=$zero_phase -order=$order -fcorner=$fcorner -inpolygon_fault=$inpolygon_fault -inpolygon_hypocenter=$inpolygon_hypocenter -high_stress_depth=$high_stress_depth -stress_parameter=$stress_parameter

    # Put the prepared input by the user into it's place    
    cd ~/inputfiles
    mv *.mod $HOMEPATH/$PROJNAME/structure
    mv *.fault $HOMEPATH/$PROJNAME/data/model_info
    mv *.mshout $HOMEPATH/$PROJNAME/data/model_info
    mv *.xyz $HOMEPATH/$PROJNAME/data/model_info
    mv *.gflist $HOMEPATH/$PROJNAME/data/station_info
    cd ~               # go back

    # make dir to contain the needed output to make waveforms in future jobs
    #mkdir preparedoutput$runnum


    # Make ruptures --- if user passes in .npy matrices recylce them

    tar -xzf distancematrices.tar.gz
    cd distancematrices    
    dcount=$(ls *.npy 2>/dev/null | wc -l)
    if [ "$dcount" = "0" ]; then
        #python3 /MudPy/examples/fakequakes/planar/mudpy_single_exec_SSE.fq.py make_ruptures -load_distances=0 -g_from_file=0 -ncpus=1 -model_name=$model_name -fault_name=$fault_name -epicenter=$epicenter -slab_name=$slab_name -mesh_name=$mesh_name -distances_name=$distances_name -utm_zone=$utm_zone -scaling_law=$scaling_law -dynamic_gflist=$dynamic_gflist -dist_threshold=$dist_threshold -nrealizations=$nrealizations -max_slip=$max_slip -hurst=$hurst -ldip=$ldip -lstrike=$lstrike -lognormal=$lognormal -slip_standard_deviation=$slip_standard_deviation -num_modes=$num_modes -rake=$rake -force_magnitude=$force_magnitude -force_area=$force_area -no_random=$no_random -time_epi=$time_epi -hypocenter=$hypocenter -force_hypocenter=$force_hypocenter -mean_slip=$mean_slip -center_subfault=$center_subfault -use_hypo_fraction=$use_hypo_fraction -source_time_function=$source_time_function -rise_time_depths=$rise_time_depths -shear_wave_fraction=$shear_wave_fraction -gf_list=$gf_list -g_name=$g_name -nfft=$nfft -dt=$dt -dk=$dk -pmin=$pmin -pmax=$pmax -kmax=$kmax -custom_stf=$custom_stf -rupture_list=$rupture_list -target_mw=$target_mw -max_slip_rule=$max_slip_rule -slip_tol=$slip_tol -shear_wave_fraction_deep=$shear_wave_fraction_deep -shear_wave_fraction_shallow=$shear_wave_fraction_shallow -zeta=$zeta -stf_falloff_rate=$stf_falloff_rate -rupture_name=$rupture_name -hot_start=$hot_start -impulse=$impulse -home=$HOMEPATH -project_name=$PROJNAME -run_name=$run_name
	python3 /MudPy/examples/fakequakes/planar/mudpy_single_exec_SSE.fq.py make_ruptures -load_distances=0 -g_from_file=0 -ncpus=1 -model_name=$model_name -fault_name=$fault_name  -slab_name=$slab_name -mesh_name=$mesh_name -distances_name=$distances_name -utm_zone=$utm_zone -scaling_law=$scaling_law -nrealizations=$nrealizations -max_slip=$max_slip -hurst=$hurst -ldip=$ldip -lstrike=$lstrike -lognormal=$lognormal -slip_standard_deviation=$slip_standard_deviation -num_modes=$num_modes -rake=$rake -force_magnitude=$force_magnitude -force_area=$force_area -time_epi=$time_epi -force_hypocenter=$force_hypocenter  -use_hypo_fraction=$use_hypo_fraction -source_time_function=$source_time_function -rise_time_depths=$rise_time_depths  -gf_list=$gf_list -g_name=$g_name -nfft=$nfft -dt=$dt -dk=$dk -pmin=$pmin -pmax=$pmax -kmax=$kmax -custom_stf=$custom_stf -rupture_list=$rupture_list -target_mw=$target_mw -max_slip_rule=$max_slip_rule  -stf_falloff_rate=$stf_falloff_rate -hot_start=$hot_start -home=$HOMEPATH -project_name=$PROJNAME -run_name=$run_name -moho_depth_in_km=$moho_depth_in_km -hf_dt=$hf_dt -duration=$duration -pwave=$pwave -zero_phase=$zero_phase -order=$order -fcorner=$fcorner -inpolygon_fault=$inpolygon_fault -inpolygon_hypocenter=$inpolygon_hypocenter -high_stress_depth=$high_stress_depth -stress_parameter=$stress_parameter
    else
	
	echo "recycling distance matrices ..."
	    
        # Move matrices to project and recycle 
        mv *.npy $HOMEPATH/$PROJNAME/data/distances         
        #python3 /MudPy/examples/fakequakes/planar/mudpy_single_exec_SSE.fq.py make_ruptures -load_distances=1 -g_from_file=0 -ncpus=$ncpus -model_name=$model_name -epicenter=$epicenter -fault_name=$fault_name -slab_name=$slab_name -mesh_name=$mesh_name -distances_name=$distances_name -utm_zone=$utm_zone -scaling_law=$scaling_law -dynamic_gflist=$dynamic_gflist -dist_threshold=$dist_threshold -nrealizations=$nrealizations -max_slip=$max_slip -hurst=$hurst -ldip=$ldip -lstrike=$lstrike -lognormal=$lognormal -slip_standard_deviation=$slip_standard_deviation -num_modes=$num_modes -rake=$rake -force_magnitude=$force_magnitude -force_area=$force_area -no_random=$no_random -time_epi=$time_epi -hypocenter=$hypocenter -force_hypocenter=$force_hypocenter -mean_slip=$mean_slip -center_subfault=$center_subfault -use_hypo_fraction=$use_hypo_fraction -source_time_function=$source_time_function -rise_time_depths=$rise_time_depths -shear_wave_fraction=$shear_wave_fraction -gf_list=$gf_list -g_name=$g_name -nfft=$nfft -dt=$dt -dk=$dk -pmin=$pmin -pmax=$pmax -kmax=$kmax -custom_stf=$custom_stf -rupture_list=$rupture_list -target_mw=$target_mw -max_slip_rule=$max_slip_rule -slip_tol=$slip_tol -shear_wave_fraction_deep=$shear_wave_fraction_deep -shear_wave_fraction_shallow=$shear_wave_fraction_shallow -zeta=$zeta -stf_falloff_rate=$stf_falloff_rate -rupture_name=$rupture_name -hot_start=$hot_start -impulse=$impulse -home=$HOMEPATH -project_name=$PROJNAME -run_name=$run_name
	python3 /MudPy/examples/fakequakes/planar/mudpy_single_exec_SSE.fq.py make_ruptures -load_distances=1 -g_from_file=0 -ncpus=$ncpus -model_name=$model_name -fault_name=$fault_name -slab_name=$slab_name -mesh_name=$mesh_name -distances_name=$distances_name -utm_zone=$utm_zone -scaling_law=$scaling_law -nrealizations=$nrealizations -max_slip=$max_slip -hurst=$hurst -ldip=$ldip -lstrike=$lstrike -lognormal=$lognormal -slip_standard_deviation=$slip_standard_deviation -num_modes=$num_modes -rake=$rake -force_magnitude=$force_magnitude -force_area=$force_area -time_epi=$time_epi -force_hypocenter=$force_hypocenter  -use_hypo_fraction=$use_hypo_fraction -source_time_function=$source_time_function -rise_time_depths=$rise_time_depths -gf_list=$gf_list -g_name=$g_name -nfft=$nfft -dt=$dt -dk=$dk -pmin=$pmin -pmax=$pmax -kmax=$kmax -custom_stf=$custom_stf -rupture_list=$rupture_list -target_mw=$target_mw -max_slip_rule=$max_slip_rule -stf_falloff_rate=$stf_falloff_rate -hot_start=$hot_start -home=$HOMEPATH -project_name=$PROJNAME -run_name=$run_name -moho_depth_in_km=$moho_depth_in_km -hf_dt=$hf_dt -duration=$duration -pwave=$pwave -zero_phase=$zero_phase -order=$order -fcorner=$fcorner -inpolygon_fault=$inpolygon_fault -inpolygon_hypocenter=$inpolygon_hypocenter -high_stress_depth=$high_stress_depth -stress_parameter=$stress_parameter
                
    fi
    
    # Move rupture files to (.rupt/.log files,ruptures.list,  .npy matrices) to preparedoutput
    cd $HOMEPATH/$PROJNAME/output
    tar -czf ruptures.tar.gz ruptures
    mv ruptures.tar.gz ~/preparedoutput$runnum

    cd $HOMEPATH/$PROJNAME/data
    cp ruptures.list ~/preparedoutput$runnum
    
    if [ "$dcount" = "0" ]; then	
        cd $HOMEPATH/$PROJNAME/data/distances
        cp *.npy ~/preparedoutput$runnum
    fi
    
    cd ~


    # Compresss the output to be used by the next jobs in the DAG
    # From the execute node's home dir it is transfrered to the home dir of the OSG submitter
    tar -czf preparedoutput$runnum.tar.gz preparedoutput$runnum

else

    # ruptures were already made and passed in. Wrap up dummy output so that the DAGman know what happened.
    echo "Ruptures were premade and passed it. No ruptures made over OSG"
    cd ~/preparedoutput$runnum
    > noout.txt
    echo "nothing made in phase A" >> noout.txt
    cd ~
    tar -czf preparedoutput$runnum.tar.gz preparedoutput$runnum

fi    
  

