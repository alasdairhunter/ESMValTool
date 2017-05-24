;
;  Requires: zg:*3*
;
load "interface_scripts/data_handling.ncl"

variable_info = True
variable_info@derived = True
variable_info@long_name="geopotential height 500hPa"
variable_info@units="m"
variable_info@map_ref_Levels = ispan(4000, 6000, 10)
variable_info@map_diff_Levels = ispan(-20, 20, 5)

undef("calculate")
function calculate(index [1] : integer,
                   variable [1] : string,
                   field_type [1] : string)
;;                 return_val [1] : logical
;; Arguments:
;;    index    - index to current infile defined in the 'interface_data/ncl.interface'-file
;;    variable - logical with releveant variable as string attribute
;;    field_type  - string with field type classification
;; Return value:
;;    data_new - logical
local tmp, dum, i, verbosity
begin
    verbosity = stringtointeger(getenv("ESMValTool_verbosity"))
    info_output("<<<<<<<< Entering z500.ncl", verbosity, 2)
    data_new = True
    tmp = read_data(index, "zg", "*3*")
    dum = extract_data(index, tmp, 1, 50000., 50000.)
;;    dum = dum/9.80665

    dum@long_name = variable_info@long_name
    dum@units = variable_info@units
    add_data_var(index, data_new, dum, variable)

    info_output(">>>>>>>> Leaving z500.ncl", verbosity, 2)
    return(data_new)
end