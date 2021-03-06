;
; Requires: co2:T3*,hus:T3*,zg:T3*
;
variable_info = True
variable_info@derived = True
variable_info@long_name  = "Column Averaged CO2"
variable_info@short_name = "XCO2"
variable_info@units      = "1e-6"
variable_info@plot_units = "ppmv"

variable_info@colormap        = "BlAqGrYeOrReVi200"
; A_laue_ax+
;variable_info@acp_cnlvl       = fspan(385.5, 400.5, 16)
;variable_info@map_ref_Levels  = fspan(380., 395., 16)
;variable_info@map_diff_Levels = fspan(-1., 16., 17)
variable_info@acp_cnlvl       = fspan(375., 405., 21)
variable_info@map_ref_Levels  = fspan(375., 405., 21)
variable_info@map_diff_Levels = fspan(-15., 15., 21)
; A_laue_ax-
variable_info@am_cnlvl        = fspan(370., 405., 29)
variable_info@eyring13_cnlvl  = fspan(385., 400., 13)
variable_info@eyring13_reflvl = fspan(378., 402., 13)

;;#############################################################################
load "interface_scripts/data_handling.ncl"
load "interface_scripts/constants.ncl"

undef("calculate")
function calculate(index[1]:integer,
                   variable[1]:string,
                   field_type[1]:string)
;;
;; Arguments
;;    index: index to current infile defined in interface_data/ncl.interface
;;    variable; logical with relevant variable as string attribute
;;    field_type: string with field type classification
;;
;; Return value
;;    data_new: logical
;;
;; Description
;;    Calculates the average-column atmospheric CO2 [1e-6].
;;
;; Caveats
;;
;; Reference
;;
;; Modification history
;;    20160308-A_wenz_sa: written.
;;
local funcname, scriptname, verbosity,  tmp1, tmp2, xco2, pre_lev, hum_lay, \
    lat, co2, con_lay, phi_lay, gra_lay, g0, eam, fac, pre_del, h2o_wet, mwet, \
    wet_col, dry_col, ll, pp
begin

    funcname = "calculate"
    scriptname = "variable_defs/xco2.ncl"
    verbosity = stringtointeger(getenv("ESMValTool_verbosity"))
    enter_msg(scriptname, funcname, 4)

    ;; Fetch data
    tmp1  = read_data(index, "co2", "T3*")
    tmp2  = read_data(index, "hus", "T3*")
    tmp3  = read_data(index, "zg", "T3*")
    con_lay = extract_data(index, tmp1, -1, 0, 0)
    pre_lev = con_lay&plev
    hum_lay = extract_data_extended(index, "hus", tmp2, -1, 0, 0)
    phi_lay = extract_data_extended(index, "zg", tmp3, -1, 0, 0)
    lat     = con_lay&lat

    ;;Constants
    eam	= 5.97219e24                          ;gravitational constant in m3 / kg / s2
    fac	= - 2. * Gnewt * eam / EARTHradius^3. ;free air correction constant (i.e. the reduction 
                                              ;of g per m, linear approximation)

    ;;approximate g at the geoid
    g0	= 9.780327 * (1. + 0.0053024 * (sin(lat / 180. * PI))^2.d - 0.0000058 * (sin(2. * lat / 180. * PI))^2.)

    ;;apply free air correction
    gra_lay = new(dimsizes(phi_lay),typeof(phi_lay))
    do ll = 0,dimsizes(phi_lay&lat)-1
        tmp = sqrt(g0(ll)^2. + 2. * fac * phi_lay(:,:,ll,:))
        gra_lay(:,:,ll,:) = tofloat(tmp)
        delete(tmp)
    end do

    ;;calculate delta pressure in Pa devided by 10^4 in order to calculate 
    ;;number of particles over 1cm^2 (not 1m^2)
    pre_del = pre_lev(: dimsizes(pre_lev) - 2) - pre_lev(1: dimsizes(pre_lev) - 1) / 100.

    ;;convert specific humidity (mass h2o / mass wet air) to 
    ;;dry air mole fraction (n_h2o / n_dryair) in 1/1
    h2o_dry = hum_lay / (1. - hum_lay) * MWair*1e-3 / MWh2o*1e-3 

    ;;convert dry mole fraction of h2o to wet mole fraction (in 1/1)
    h2o_wet = h2o_dry / (1. + h2o_dry)

    ;;calculate molar mass of wet air
    mwet    = MWair*1e-3 * (1. - h2o_wet) + MWh2o*1e-3 * h2o_wet 

    ;;calculate number of wet air particles per layer
    wet_col = new(dimsizes(phi_lay),typeof(phi_lay))
    do pp = 0,dimsizes(phi_lay&plev)-2
        tmp = pre_del(pp) * Navo / mwet(:,pp,:,:) / gra_lay(:,pp,:,:)
        wet_col(:,pp,:,:) = tofloat(tmp)
        delete(tmp) 
    end do

    ;;calculate number of dry air particles per layer
    dry_col = wet_col * (1. - h2o_wet) 

    ;;calculate number of gas particles per layer
    gas_col = dry_col * con_lay / 1e6 
	
    ;;return xgas in ppm
    xco2 = dim_avg_n_Wrap(gas_col,1) / dim_avg_n_Wrap(dry_col,1) * 1e6 
    xco2!0 = "time"
    xco2!1 = "lat"
    xco2!2 = "lon"
    xco2&time = con_lay&time
    xco2&lat  = con_lay&lat
    xco2&lon  = con_lay&lon

    ;xco2 = dim_avg_n_Wrap(co2_t,1)

    ;; Set metadata and return
    xco2@long_name = variable_info@long_name
    xco2@units = variable_info@units
    data_new = True
    add_data_var(index, data_new, xco2, variable)

    leave_msg(scriptname, funcname, 4)
    return(data_new)

end
