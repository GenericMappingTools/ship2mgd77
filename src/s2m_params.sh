# Settings for ship2mgd77.sh

# System specific variables (edit right hand side of these assignments)
shipcode="/Users/mith/Programs/GMTdev/ship2mgd77/bin" # Path to directory where ship2mgd77.sh and udmerge and lopassvel binaries live
underwaypath="km1609_day342"    # Path to directory with raw underway data
outputdatapath="archive_data"    # Path to output directory with merged file

# Cruise specific variables (edit these)
# Or: as in this script pull these values from inhouse tables
country="USA" # Source country (18 char)
source_institution="SOEST University of Hawaii" # Institution responsible for collecting data (39 char)
funder="NSF" # Funding agency (20 char)
chiefsci="P Wessel" # Chief scientst name(s) (32 char)
vessel="Kilo Moana" # Vessel name (21 char)
project_cruise_leg="Test Data KM1609 Day 342" # Verbose project/leg name (58 char)
port1="Apia, American Samoa" # Departure port city, country (32 char)
port2="Apia, American Samoa" # Arrival port city, country (30 char)
navinstr="DGPS" # Navigation instrumentation (e.g., celestial, GPS, DGPS, USBL, etc) (40 char)
sonar1="Kongsberg EM122" # Deep water multibeam sonar manufacturer and exact model (40 char incl sonar1 and sonar2)
sonar2="/EM710" # Shallow water multibeam sonar manufacturer and exact model (model only if manufacturer same as deep)
gravimeter="Bell Aerospace BGM-3" # Gravimeter manufacturer and exact model (40 char)
magnetometer="Geometrics Cesium Mag G-882" # Magnetometer manufacturer and exact model (40 char)

# Digitization parameters
sample2depthtime=0 #  Set to 0 for mag/grav at sample intervals below or 1 to resample mag/grav to depth times
bgm3grav_sample_interval=15 # gravity digitization interval (sec) [15]
mag_sample_interval=15 # magnetic digitization interval (sec) [15]

# Navigation parameters
filternav=0 # 1 activates nav filtering, 0 deactivates filtering [0]
filternav_fw=7 # length of nav filter width (seconds) [7]

# Gravity parameters
bgm3grav_fw=360 # gravity filter width - raw counts too noisy and should be filtered according to sea state (sec) [360]
g_pier35alpha=978927.887 # Honolulu absolute gravity [978927.887]
# University of Hawaii BGM3 specific constants (Warning: gravity values produced via these constants will not be valid)
bgm3scale="5.07" # BGM3 constants (scale/bias are protected information - actual values differ) [5.07]
bgm3bias="853500" # BGM3 constants (scale/bias are protected information - actual values differ) [853500]

# Magnetic parameters
compute_diurnal_correction=0 # 1 to compute diurnal corrections (if mag available) or 0 to skip
mag_fw=60 # magnetic filter width (sec) [60]
# University of Hawaii G882 cesium magnetometer specific constants
g882_min_sigstrength=100 # Arbitrary minimum signal strength for G882 magnetometer
# G-882 cesium mag sensor depth constants (Warning: msd calculation will differ for other sensors)
m_scale=0.034881 # mag sensor depth = reported + reported * m_scale + m_bias
m_bias=3.84 # mag sensor depth = reported + reported * m_scale + m_bias
