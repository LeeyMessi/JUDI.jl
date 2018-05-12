# Test 2D modeling
# The receiver positions and the source wavelets are the same for each of the four experiments.
# Author: Philipp Witte, pwitte@eos.ubc.ca
# Date: January 2017
#

using PyCall, PyPlot, JUDI.TimeModeling, SeisIO

## Set up model structure
n = (120,100)	# (x,y,z) or (x,z)
d = (10.,10.)
o = (0.,0.)

# Velocity [km/s]
v = ones(Float32,n) + 0.4f0
v0 = ones(Float32,n) + 0.4f0
v[:,Int(round(end/2)):end] = 4.f0

rho = ones(Float32,n)
rho[:,Int(round(end/2)):end] = 1.2f0

# Slowness squared [s^2/km^2]
m = (1./v).^2
m0 = (1./v0).^2
dm = vec(m - m0)

# Setup info and model structure
nsrc = 2	# number of sources
model = Model(n,d,o,m; rho=rho)	# to include density call Model(n,d,o,m,rho)
model0 = Model(n,d,o,m0; rho=rho)

## Set up receiver geometry
nxrec = 60
xrec = linspace(50.,500.,nxrec)
yrec = 0.
zrec = linspace(50.,50.,nxrec)

# receiver sampling and recording time
timeR = 1000.	# receiver recording time [ms]
dtR = 2.	# receiver sampling interval

# Set up receiver structure
recGeometry = Geometry(xrec,yrec,zrec;dt=dtR,t=timeR,nsrc=nsrc)

## Set up source geometry (cell array with source locations for each shot)
xsrc = convertToCell(linspace(100.,20.,nsrc))
ysrc = convertToCell(linspace(0.,0.,nsrc))
zsrc = convertToCell(linspace(20.,20.,nsrc))

# source sampling and number of time steps
timeS = 1000.
dtS = 2.	# receiver sampling interval

# Set up source structure
srcGeometry = Geometry(xsrc,ysrc,zsrc;dt=dtS,t=timeS)

# setup wavelet
f0 = 0.01
wavelet = ricker_wavelet(timeS,dtS,f0)

# Set up info structure for linear operators
ntComp = get_computational_nt(srcGeometry,recGeometry,model)
info = Info(prod(n),nsrc,ntComp)

######################## WITH DENSITY ############################################

# Keep data in memory
println("Test modeling without density, data in RAM")

opt = Options(limit_m = true,
              buffer_size = 100f0
			  )

# Setup operators
Pr = judiProjection(info,recGeometry)
F = judiModeling(info,model;options=opt)
F0 = judiModeling(info,model0;options=opt)
Ps = judiProjection(info,srcGeometry)
q = judiVector(srcGeometry,wavelet)

# Combined operator Pr*F*Ps'
Ffull = judiModeling(info,model,srcGeometry,recGeometry)

# Nonlinear modeling
d1 = Pr*F*Ps'*q	# equivalent to d = Ffull*q
qad = Ps*F'*Pr'*d1

# Linearized modeling
J = judiJacobian(Pr*F0*Ps',q)	# equivalent to J = judiJacobian(Ffull,q)
dD = J*dm
rtm = J'*dD

# fwi objective function
f,g = fwi_objective(model0,q,d1)
f,g = fwi_objective(model0,subsample(q,1),subsample(d1,1))

# Subsampling
dsub1 = subsample(d1,1)
dsub2 = subsample(d1,[1,2])
Fsub1 = subsample(F,1)
Fsub2 = subsample(F,[1,2])
Jsub1 = subsample(J,1)
Jsub2 = subsample(J,[1,2])
Ffullsub1 = subsample(Ffull,1)
Ffullsub2 = subsample(Ffull,[1,2])
Psub1 = subsample(Pr,1)
Psub2 = subsample(Pr,[1,2])

# vcat, norms, dot
dcat = [d1,d1]
norm(d1)
dot(d1,d1)


#########################################################################
# Save data to segy files
println("Test modeling, save data to disk")


# Options structures
opt = Options(limit_m = true,
              buffer_size = 100f0,
              save_data_to_disk=true,
			  file_path=pwd(),	# path to files
			  file_name="shot_record"	# saves files as file_name_xsrc_ysrc.segy
			  )

opt0 = Options(limit_m = true,
              buffer_size = 100f0,
              save_data_to_disk=true,
			  file_path=pwd(),	# path to files
			  file_name="linearized_shot_record"	# saves files as file_name_xsrc_ysrc.segy
			  )

# Setup operators
F = judiModeling(info,model;options=opt)
F0 = judiModeling(info,model0;options=opt0)

# Nonlinear modeling
dsave = Pr*F*Ps'*q	# equivalent to d = Ffull*q
qad = Ps*F'*Pr'*d1

# Linearized modeling
J = judiJacobian(Pr*F0*Ps',q)	# equivalent to J = judiJacobian(Ffull,q)
dDsave = J*dm
rtm = J'*dD

# Subsampling
dsub1 = subsample(d1,1)
dsub2 = subsample(d1,[1,2])
Fsub1 = subsample(F,1)
Fsub2 = subsample(F,[1,2])
Jsub1 = subsample(J,1)
Jsub2 = subsample(J,[1,2])
Ffullsub1 = subsample(Ffull,1)
Ffullsub2 = subsample(Ffull,[1,2])
Psub1 = subsample(Pr,1)
Psub2 = subsample(Pr,[1,2])

# fwi objective function
f,g = fwi_objective(model0,q,dsave)
f,g = fwi_objective(model0,subsample(q,1),subsample(dsave,1))

# vcat, norms, dot
dcat = [d1,d1]
norm(d1)
dot(d1,d1)

rm("shot_record_100.0_0.0.segy")
rm("shot_record_20.0_0.0.segy")
rm("linearized_shot_record_100.0_0.0.segy")
rm("linearized_shot_record_20.0_0.0.segy")

