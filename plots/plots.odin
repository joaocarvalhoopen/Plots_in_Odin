// Project:     Plots_in_Odin
//
// Description: This is a small package to make plots in the Odin programming
//              language. Currently it only supports: 
//                - Line plots
//                - Scatter plots
//              But in the future it will possibly support:
//                - Histogram plots
//              The plots are saved in .png files of a user specified resolution.
//              The plots are draw to a image buffer and then saved to a png file.
//              So if one whishes, one could draw the plots to a window instead of
//              saving them to a file, with some small custom work from the user
//              of the package. It's the field plot.image_buffer and it contains
//              RGBA values, of plot.size_x x plot.size_y.
//              Or use the function plot_get_image_buffer() to get the image buffer.
//              I only tested this package in Linux, but it should work in Windows,
//              and MacOS systems, because it only uses the Core lib and two stb libs
//              from the Vendors lib of Odin.
//              In Linux I had to compile the "odin/vendors/stb/image/" C module by
//              executing the makefile that is in that diretory. The error that it
//              gives, when the library is not compiled is a linker error, that is
//              I have the option to see the linker errors when I compile the program.
//              This main.odin file contains several examples of the use of this
//              plots_in_odin package.
//
// Author:      João Nuno Carvalho
// Date:        2023.12.03
// License:     MIT Open Source License
//
// Have fun! :-)
//


package plots

import png "vendor:stb/image"
import "vendor:stb/easy_font"
import "core:fmt"
import "core:strings"
import "core:slice"


// This point is used when we don't have a value for the point.
POINT_NOT_DEFINED_YY : f64 : 42.42424242e42
// Y_MINIMUM_VALUE : f64 = -1e+9
// Y_MAXIMUM_VALUE : f64 =  1e+9

Y_MINIMUM_VALUE : f64 = -1e-10
Y_MAXIMUM_VALUE : f64 =  1e10

// Under the media of 0.5 percentile or 99.5 percentile, the values are considered outliers not visible.
MAGIC_NUMBER_THAT_DEFINES_NUMBER_NOT_VISIBLE : f64 = 1000

// Internal color
RGBA :: struct #packed {
    r    : u8,
    g    : u8,
    b    : u8,
    a    : u8,
}

// External Color
ExtColor :: struct {
    white     : RGBA,
    black     : RGBA,
    gray      : RGBA,
    gray_dark : RGBA,
    blue      : RGBA,
    green     : RGBA,
    red       : RGBA,
    yellow    : RGBA
}

color := ExtColor{
    white     = RGBA{ r=255, g=255, b=255, a = 255 },
    black     = RGBA{ r=0,   g=0,   b=0,   a = 255 },
    gray      = RGBA{ r=128, g=128, b=128, a = 255 },
    gray_dark = RGBA{ r=50,  g=50,  b=50,  a = 255 },
    blue      = RGBA{ r=0,   g=0,   b=255, a = 255 },
    green     = RGBA{ r=0,   g=150, b=0,   a = 255 },
    red       = RGBA{ r=255, g=0,   b=0,   a = 255 },
    yellow    = RGBA{ r=255, g=255, b=0,   a = 255 },
}

Pixel :: struct #raw_union {
    val      : u32,         // 32-bit unsigned integer
    val_RGBA : RGBA,        // As separate componentes.
}

PlotType :: enum {
    Line,
    Scatter,
    Bar
}

// Represents one plot.
Plot :: struct {
    type             : PlotType,
    size_x           : int,
    size_y           : int,
    background_color : RGBA,
    digits_color     : RGBA,
    xx_units         : string,     
    yy_units         : string,

    // This is the RGBA image data buffer.
    img_buffer       : [dynamic]Pixel,

    // This are the y_values for each instance of the plots.
    plot_instances   : [dynamic]PlotInstance,

    // This values are common to all instances of plots.
    x_values_vec     : []f64,
    index_x0         : int,
    x_step           : f64,

    y_min_union      : f64,
    y_max_union      : f64,
    y_range_union    : f64,
    y_factor_union   : f64,    

    // Only used in scatter plots PlotType.Scatter.
    // Has the fusion of all scatter plots instances.
    x_min_union      : f64,
    x_max_union      : f64,
    x_range_union    : f64,
    x_factor_union   : f64,
}

PlotInstance :: struct {
    // Defines this trace type.
    // PlotType.Line, PlotType.Scatter, PlotType.Bar
    trace_type         : PlotType,

    xx                 : [2]f64,
    yy                 : Func_Type,

    // Defines this trace type.
    point_tuple_array  : ^Point_Vec,    // Only for use in PlotType.Scatter.

    legend             : string,
    legend_pos         : [2]int,
    p_color            : RGBA,
    trace_size_point_n : PointN,

    xx_values_that_exist_vec : []bool,
    y_values_vec             : []f64,
    y_min                    : f64,
    y_max                    : f64,
    
    // Only used in scatter plots PlotType.Scatter.
    x_min                    : f64,
    x_max                    : f64,
}

Func_Type :: proc ( x : f64 ) -> f64

get_1d_pos_from_xy :: proc ( x : int, y : int, size_x : int, size_y : int, invert_y : bool = true ) -> int {
    // return x + y * size_x
    if invert_y {
        return x + ( (size_y - 1) - y ) * size_x
    }
    return x + y * size_x
}

paint_background :: proc ( plot : ^Plot, color : RGBA ) {
    for y in 0 ..< plot.size_y {
        for x in 0 ..< plot.size_x {
            index := get_1d_pos_from_xy( x, y, plot.size_x, plot.size_y )
            plot.img_buffer[ index ] = Pixel{ val_RGBA = plot.background_color }
        }
    }
} 

// percentile: Percentile to compute (value between 0 and 100)
// return: The percentile value in the data
percentile :: proc ( data : []f64, percentile: f64 ) -> f64 {

    // Add the data to a temporary slice
    sorted_data := slice.clone( data )
    defer delete( sorted_data )

    slice.sort( sorted_data )

    // Calculate the index
    index := f64( len(sorted_data ) - 1 ) * percentile / 100

    // Find the values at the index
    lower_index := int( index )
    upper_index := lower_index + 1

    if upper_index < len( sorted_data ) {
        // Interpolate between the two surrounding values.
        return sorted_data[ lower_index ] + 
               ( sorted_data[ upper_index ] - sorted_data[ lower_index ] ) *
               ( index - f64( lower_index ) )
    } else {
        // If the index is at the end of the list, return the last value.
        return sorted_data[ lower_index ]
    }
}

// percentile: Percentile to compute (value between 0 and 100)
// return: The percentile value in the data
percentile_double :: proc ( data : []f64, percentile_values: [2]f64 ) ->
                     ( lower_value : f64, upper_value : f64 ) {

    // Add the data to a temporary slice
    sorted_data := slice.clone( data )
    defer delete( sorted_data )

    slice.sort( sorted_data )

    for percentile, result_num in percentile_values {
        // Calculate the index
        index := f64( len( sorted_data ) - 1 ) * percentile / 100

        // Find the values at the index
        lower_index := int( index )
        upper_index := lower_index + 1

        res : f64

        if upper_index < len( sorted_data ) {
            // Interpolate between the two surrounding values.
            res = sorted_data[ lower_index ] +
                  ( sorted_data[ upper_index ] - sorted_data[ lower_index ] ) *
                  ( index - f64( lower_index ) )
        } else {
            // If the index is at the end of the list, return the last value.
            res = sorted_data[ lower_index ]
        }

        if result_num == 0 {
            lower_value = res
        } else if result_num == 1 {
            upper_value = res
        }
    } 

    return lower_value, upper_value
}

// Detects values that are outside the 95% of the values in the data.
// return: A list of outlier values
detect_outliers :: proc ( data : []f64 ) -> 
       ( outliers_lower : []int, outliers_lower_max : f64,
         outliers_upper : []int, outliers_upper_min : f64 ) {

    // Calculate the 0.5th and 99.5th percentiles
    // lower_bound, upper_bound := percentile_double( data, [2]f64{ 0.5, 99.5 } )
    lower_bound, upper_bound := percentile_double( data, [2]f64{ 0.2, 98.0 } )

    outliers_lower_int := make( [ dynamic ]int, 0, 10 )
    outliers_upper_int := make( [ dynamic ]int, 0, 10 )

    // Identify outliers
    for val, index in data {
        if val < lower_bound {
            append( & outliers_lower_int, index )
        } else if val > upper_bound {
            append( & outliers_upper_int, index )
        }
    }

    outliers_lower     = outliers_lower_int[ : ]
    outliers_lower_max = lower_bound
    outliers_upper     = outliers_upper_int[ : ]
    outliers_upper_min = upper_bound
    return outliers_lower, outliers_lower_max, outliers_upper, outliers_upper_min
}

media :: proc ( outliers : []int, y_values_vec : []f64 ) -> ( outliers_media : f64 ) {
    // Calculate the media of the outliers_lower.
    outliers_media = 0.0
    for i in 0 ..< len( outliers ) {
        outliers_media += y_values_vec[ outliers[ i ] ]
    }

    outliers_media /= f64( len( outliers ) )
    return outliers_media
}

get_x_range_values :: proc ( xx : [2]f64, size_x : int ) ->  
                    ( x_values_vec : []f64, index_x0 : int, x_step : f64, xx_values_that_exist_vec : []bool  ) {
    x_min := xx[ 0 ]
    x_max := xx[ 1 ]
    x_range := abs( x_max - x_min )
    x_step = x_range / f64( size_x )
    x_values_vec = make( []f64, size_x )
    delta_to_zero := f64( 1e+42 )
    index_x0 = 0
    for i in 0 ..< size_x {
        x_values_vec[ i ] = x_min + x_step * f64( i )

        // Find index in image data point of x=0.
        if x_min <= 0 && x_max >= 0 {
            delta_tmp := abs( x_values_vec[ i ] - 0 )
            if delta_tmp < delta_to_zero {
                delta_to_zero = delta_tmp
                index_x0 = i
            }
        }
    }

    if index_x0 == 0 {
        if x_min > 0 {
            index_x0 = int( ( f64( 0 - x_min ) / f64( x_range ) ) * f64( size_x ) )
        } else if x_max < 0 {
            index_x0 = int( f64( size_x - 1 ) + ( f64( 0 - x_max ) / f64( x_range ) ) * f64( size_x ) )
        }
    }

    xx_values_that_exist_vec = make( []bool, size_x )
    slice.fill( xx_values_that_exist_vec, true )
    return x_values_vec, index_x0, x_step, xx_values_that_exist_vec
}

get_x_range_values_from_values :: proc ( xx : []f64, size_x : int ) ->
            ( x_values_vec : []f64, index_x0 : int, x_step : f64, x_min : f64, x_max : f64,
              xx_values_that_exist_vec : []bool  ) {
    
    // Check that the values are always decreasing or at least constant 1 <= 2.
    for i in 1 ..< len( xx ) {
        if xx[ i - 1 ] > xx[ i ] {
            panic( "Error : The values of xx are not always decresing  .... xx[ i - 1 ] <= xx[ i ]" )
        }
    }       

    ok : bool
    x_min, ok = slice.min( xx )
    if !ok {
        panic( "slice.min() failed" )
    }
    
    x_max, ok = slice.max( xx )
    if !ok {
        panic( "slice.max() failed" )
    }

    x_range := abs( x_max - x_min ) 
    x_step = x_range / f64( size_x )
    x_values_vec = make( []f64, size_x )
    delta_to_zero := f64( 1e+42 )
    index_x0 = 0

    // Generates one x value for each pixel, of the image in the XX axies.
    for i in 0 ..< size_x {
        x_values_vec[ i ] = x_min + x_step * f64( i )

        // Find index in image data point of x=0.
        if x_min <= 0 && x_max >= 0 {
            delta_tmp := abs( x_values_vec[ i ] - 0 )
            if delta_tmp < delta_to_zero {
                delta_to_zero = delta_tmp
                index_x0 = i
            }
        }
    }

    // Allocates the array of booleans.
    xx_values_that_exist_vec = make( []bool, size_x )

    // Make the match between the nearest xx values to the x_value_vec.
    x_values_vec[ 0 ] = xx[ 0 ]
    xx_values_that_exist_vec[ 0 ] = true
    x_values_vec[ len( x_values_vec ) - 1 ] = xx[ len( xx ) - 1 ]
    xx_values_that_exist_vec[ len( x_values_vec ) - 1 ] = true
    curr_x_values_index := 0
    for i in 1 ..< ( len( xx ) - 1 ) {

        // fmt.printf(" i : %v,    xx[ %v ] = %v\n", i, i , xx[ i ] )

        // Advance until the correct x_value_vec ponint, that has the nearest value to xx[ i ]. 
        flag_delta_last_greater_then_delta_next := true
        for flag_delta_last_greater_then_delta_next {              
            
            delta_last := abs( xx[ i ] - x_values_vec[ curr_x_values_index ] )
            delta_next := abs( xx[ i ] - x_values_vec[ curr_x_values_index + 1 ] )

            if delta_last >= delta_next {
                curr_x_values_index += 1
                if curr_x_values_index == ( len( x_values_vec ) - 1 ) {
                    panic( "curr_x_values_index == ( len( x_values_vec ) - 1 )" )
                }
            } else {
                // delta_last < delta_next
                // If not the first nor the last value fill's the values.
                
                if curr_x_values_index != 0 && curr_x_values_index != ( len( x_values_vec ) - 1 ) {
                    x_values_vec[ curr_x_values_index  ] = xx[ i ]
                    xx_values_that_exist_vec[ curr_x_values_index ] = true
                }
                flag_delta_last_greater_then_delta_next = false
            }
        }
    }

    if index_x0 == 0 {
        if x_min > 0 {
            index_x0 = int( ( f64( 0 - x_min ) / f64( x_range ) ) * f64( size_x ) )
        } else if x_max < 0 {
            index_x0 = int( f64( size_x - 1 ) + ( f64( 0 - x_max ) / f64( x_range ) ) * f64( size_x ) )
        }
    }

    return x_values_vec, index_x0, x_step, x_min, x_max, xx_values_that_exist_vec
}

fill_data_vec :: proc ( x_values_vec: []f64, yy : Func_Type, yy_limits : ^[2]f64 ) ->
        ( y_values_vec : []f64, y_min : f64, y_max : f64 ) {

    // POINT_NOT_DEFINED_YY
    
    // Calculate the y_values_vec.
    y_values_vec = make( []f64, len( x_values_vec ) )
    for i in 0 ..< len( x_values_vec ) {
        y_values_vec[ i ] = yy( x_values_vec[ i ] )
    }

    // Detect the outliers.
    // Calculate the max of outlier_lower and the min of the outilers_upper.
    outliers_lower, outliers_lower_max, outliers_upper, outliers_upper_min := detect_outliers( y_values_vec )
    defer delete( outliers_lower )
    defer delete( outliers_upper )

    // Calculate the medias of the outliers.
    // outliers_lower_media := media( outliers_lower, y_values_vec )
    // outliers_upper_media := media( outliers_upper, y_values_vec )

    // Find the minimum and maximum values of the y_values_vec.
    y_min = f64( 1e42 )
    y_max = f64( -1e42 )

    yy_limits_min : f64 = 0 
    yy_limits_max : f64 = 0

    yy_magic_min : f64 = 0
    yy_magic_max : f64 = 0

    if yy_limits != nil {
        // Manual limits to the values.
        yy_limits_min = yy_limits[ 0 ]
        yy_limits_max = yy_limits[ 1 ]    
    } else {
        // Automatic limits to the values.
        yy_magic_min = outliers_lower_max - abs( outliers_lower_max ) * MAGIC_NUMBER_THAT_DEFINES_NUMBER_NOT_VISIBLE
        yy_magic_max = outliers_upper_min + abs( outliers_upper_min ) * MAGIC_NUMBER_THAT_DEFINES_NUMBER_NOT_VISIBLE
    }

    for i in 0 ..< len( y_values_vec ) {
        if y_values_vec[ i ] < y_min {

            if yy_limits != nil {
                // Manual limits to the values.
                if y_values_vec[ i ] < yy_limits_min {
                    y_values_vec[ i ] = POINT_NOT_DEFINED_YY
                    continue
                }
            } else {
                // Automatic limits to the values.
                if y_values_vec[ i ] < yy_magic_min {
                    y_values_vec[ i ] = POINT_NOT_DEFINED_YY
                    continue
                }
            }
            y_min = y_values_vec[ i ]
        }

        if y_values_vec[ i ] > y_max {
            if yy_limits != nil {
                // Manual limits to the values.
                if y_values_vec[ i ] > yy_limits_max {
                    y_values_vec[ i ] = POINT_NOT_DEFINED_YY
                    continue
                }
            } else {
                // Automatic limits to the values.
                if y_values_vec[ i ] > yy_magic_max {
                    y_values_vec[ i ] = POINT_NOT_DEFINED_YY
                    continue
                }
            }
            y_max = y_values_vec[ i ]
        }
    }

    return y_values_vec, y_min, y_max
}

plot_create :: proc ( type : PlotType, size_x : int, size_y : int,
                      background_color : RGBA,
                      digits_color     : RGBA,
                      xx_units         : string,      
                      yy_units         : string ) -> Plot {

    img_buffer := make( [dynamic]Pixel, size_x * size_y )

    plot_instances := make( [dynamic]PlotInstance, 0, 3 )

    plot := Plot{
        type             = type,
        size_x           = size_x,
        size_y           = size_y,
        background_color = background_color,
        digits_color     = digits_color,
        xx_units         = xx_units,
        yy_units         = yy_units,

        img_buffer       = img_buffer,
        plot_instances   = plot_instances,
    }

    paint_background( &plot, plot.background_color ) 

    return plot
}

plot_destroy :: proc ( plot : ^Plot ) {
    // Delete the image buffer
    if plot.img_buffer != nil {
        delete( plot.img_buffer )
        plot.img_buffer = nil;
    }
    // Delete the common x_values_vec.
    if plot.x_values_vec != nil {
        delete( plot.x_values_vec )
        plot.x_values_vec = nil;
    }
    // Delete the instances vec.
    if plot.plot_instances != nil {
        // Delete the y_values_vec of each instance.
        for i in 0 ..< len( plot.plot_instances ) {
            plot_instance := plot.plot_instances[ i ]
            if plot_instance.y_values_vec != nil {
                delete( plot_instance.y_values_vec )
                plot_instance.y_values_vec = nil;
            }
            // Delete the xx_values_that_exist_vec of each instance.
            if plot_instance.xx_values_that_exist_vec != nil {
                delete( plot_instance.xx_values_that_exist_vec )
                plot_instance.xx_values_that_exist_vec = nil;
            }
        }
        
        // Delete the instance of vec.
        delete( plot.plot_instances )
        plot.plot_instances = nil;
    }
}

// The number of pixels in with of the cross image of the pixel.
PointN :: enum {
    P_1,
    P_3,
    P_5,
    P_7,
    P_9,
    P_11,
    P_13,
    P_15,
    P_17,
}

plot_point :: proc ( point_n : PointN, plot :^Plot, x, y : int, p_color : RGBA ) {

    // Plot the point.
    if y >= 0 && y < plot.size_y && x >= 0 && x < plot.size_x {
        index := get_1d_pos_from_xy( x, y, plot.size_x, plot.size_y, invert_y = false )
        plot.img_buffer[ index ] = Pixel{ val_RGBA = p_color }
    }

    neibourhood_size := 0
    switch point_n {
        case PointN.P_1  : neibourhood_size = 0;
        case PointN.P_3  : neibourhood_size = 1;
        case PointN.P_5  : neibourhood_size = 2;
        case PointN.P_7  : neibourhood_size = 3;
        case PointN.P_9  : neibourhood_size = 4;
        case PointN.P_11 : neibourhood_size = 5;
        case PointN.P_13 : neibourhood_size = 7;
        case PointN.P_15 : neibourhood_size = 9;
        case PointN.P_17 : neibourhood_size = 11;

    }

    for i in 1 ..= neibourhood_size {
        // Plot point above - i.
        if y_minus_i := y - i; y_minus_i >= 0 && y_minus_i < plot.size_y && x >= 0 && x < plot.size_x {
            index := get_1d_pos_from_xy( x, y_minus_i, plot.size_x, plot.size_y, invert_y = false )
            plot.img_buffer[ index ] = Pixel{ val_RGBA = p_color }
        }

        // Plot point below + i.
        if y_plus_i := y + i; y_plus_i < plot.size_y && y_plus_i >= 0 && x >= 0 && x < plot.size_x {
            index := get_1d_pos_from_xy( x, y_plus_i, plot.size_x, plot.size_y, invert_y = false )
            plot.img_buffer[ index ] = Pixel{ val_RGBA = p_color }
        }

        // Plot point left - i.
        if x_minus_i := x - i; x_minus_i >= 0 && x_minus_i < plot.size_x && y >= 0 && y < plot.size_y {
            index := get_1d_pos_from_xy( x_minus_i, y, plot.size_x, plot.size_y, invert_y = false )
            plot.img_buffer[ index ] = Pixel{ val_RGBA = p_color }
        }
        
        // Plot point right + i.
        if x_plus_i := x + i; x_plus_i < plot.size_x && x_plus_i >= 0 && y >= 0 && y < plot.size_y {
            index := get_1d_pos_from_xy( x_plus_i, y, plot.size_x, plot.size_y, invert_y = false )
            plot.img_buffer[ index ] = Pixel{ val_RGBA = p_color }
        }
    }

}

XX_Range :: union {
    [2]f64,
    []f64,
}

plot_line :: proc ( plot: ^Plot,
                    xx_p : XX_Range,
                    yy : Func_Type,
                    yy_limits : ^[2]f64,
                    legend : string,
                    legend_pos : [2]int,
                    p_color : RGBA,
                    trace_size_point_n : PointN = PointN.P_3 ) {

    // plot := plot

    // Defines this trace type.
    trace_type : PlotType = PlotType.Line

    xx_values_that_exist_vec : []bool
    
    x_values_vec : []f64
    index_x0     : int
    x_step       : f64
    
    x_min        : f64
    x_max        : f64
    
    switch v in xx_p {
        case [2]f64 :
            // Calculate the index_x0 were in image pixel coordenates is the x0 axis.
            xx_tmp, ok := xx_p.( [2]f64 )
            if !ok {
                panic( "xx.( [2]f64 ) failed - array of range min_val and max_val" )
            }
            x_min = xx_tmp[ 0 ]
            x_max = xx_tmp[ 1 ]
            x_values_vec, index_x0, x_step, xx_values_that_exist_vec =
                        get_x_range_values( xx_tmp, plot.size_x ) 

        case []f64 :
            xx_tmp, ok := xx_p.( [ ]f64 )
            if !ok {
                panic( "xx.( [ ]f64 ) failed - vector of values" )
            }
            // Calculate the index_x0 were in image pixel coordenates is the x0 axis.
            x_values_vec, index_x0, x_step, x_min, x_max, xx_values_that_exist_vec =
                    get_x_range_values_from_values( xx_tmp, plot.size_x ) 
    }

    y_values_vec, y_min, y_max := fill_data_vec( x_values_vec, yy, yy_limits )

    // Set the x_instance values to the main plot, because the X_values are common to all instances.
    if plot.x_values_vec == nil {
        plot.x_values_vec = x_values_vec
        plot.index_x0     = index_x0
        plot.x_step       = x_step
    }

    xx := [2]f64{ x_min, x_max }

    // Sanity check.
    // Check if the x_min and x_max of the plot instance are equal to the previous plot instance.
    // Because this is checked each time the plot is added, it will check the consistency of x_min
    // and x_max of all the plot instances.
    if len( plot.plot_instances ) > 0 {
        instance := plot.plot_instances[ len( plot.plot_instances ) - 1 ]
        prev_x_min := instance.xx[ 0 ]
        prev_x_max := instance.xx[ 1 ]
        if x_min != prev_x_min || x_max != prev_x_max {
            panic( "Error : The x_min and x_max of the plot instance are not equal to the previous plot instance" )
        }
    }

    // Create the instance.
    plot_instance := PlotInstance{
        trace_type               = trace_type,   // PlotType.Line
        xx                       = xx,
        yy                       = yy,

        point_tuple_array        = nil,      // Only for use in PlotType.Scatter, so not use in the case of this PlotType.Line.

        legend                   = legend,
        legend_pos               = legend_pos,
        p_color                  = p_color,
        trace_size_point_n       = trace_size_point_n,
        xx_values_that_exist_vec = xx_values_that_exist_vec,
        y_values_vec             = y_values_vec,
        y_min                    = y_min,
        y_max                    = y_max,
        x_min                    = x_min,
        x_max                    = x_max,
    }

    // Add the instance to the Vector of instances.
    append( & plot.plot_instances, plot_instance )
}

plot_yy_fusion :: proc ( plot: ^Plot ) {
    for i in 0 ..< len( plot.plot_instances ) {
        plot_instance := plot.plot_instances[ i ]

        // Make the union of the y_min and y_max of all plot_instances.
        if i == 0 {
            plot.y_min_union = plot_instance.y_min
            plot.y_max_union = plot_instance.y_max
        } else {
            if plot_instance.y_min < plot.y_min_union {
                plot.y_min_union = plot_instance.y_min
            }
            if plot_instance.y_max > plot.y_max_union {
                plot.y_max_union = plot_instance.y_max
            }
        }
    }

    // Give a 5 % margin all arround the plot, by increasing 5 % the y_min and y_max.
    // plot.y_min_union = plot.y_min_union - abs( plot.y_min_union ) * 0.05
    // plot.y_max_union = plot.y_max_union + abs( plot.y_max_union ) * 0.05

    // Calculate factor to scale y-values to plot y-size.
    plot.y_range_union  = plot.y_max_union - plot.y_min_union
    plot.y_factor_union = 1.0 / abs( plot.y_range_union )    
}

plot_xx_fusion :: proc ( plot: ^Plot ) {

    plot := plot

    for i in 0 ..< len( plot.plot_instances ) {
        plot_instance := plot.plot_instances[ i ]

        // Make the union of the y_min and y_max of all plot_instances.
        if i == 0 {
            plot.x_min_union = plot_instance.x_min
            plot.x_max_union = plot_instance.x_max
        } else {
            if plot_instance.x_min < plot.x_min_union {
                plot.x_min_union = plot_instance.x_min
            }
            if plot_instance.x_max > plot.x_max_union {
                plot.x_max_union = plot_instance.x_max
            }
        }
    }

    // Give a 5 % margin all arround the plot, by increasing 5 % the y_min and y_max.
    // plot.x_min_union = plot.x_min_union - abs( plot.x_min_union ) * 0.05
    // plot.x_max_union = plot.x_max_union + abs( plot.x_max_union ) * 0.05

    // Calculate factor to scale y-values to plot y-size.
    plot.x_range_union  = plot.x_max_union - plot.x_min_union
    plot.x_factor_union = 1.0 / abs( plot.x_range_union )    
}

print_plot_struct :: proc ( plot : ^Plot, index_x0 : int, index_y0 : f64 ) {
    fmt.printf( "index_x0 : %v\n", index_x0)
    fmt.printf( "index_y0 : %v\n", index_y0)
    
    // Plot x values.

    fmt.printf( "\nplot.x_min_union : %v\n",  plot.x_min_union)
    fmt.printf( "plot.x_max_union : %v\n",    plot.x_max_union)
    fmt.printf( "plot.x_range_union : %v\n",  plot.x_range_union)
    fmt.printf( "plot.x_factor_union : %v\n", plot.x_factor_union)
    fmt.printf( "plot.size_x : %v\n",         plot.size_x)
    fmt.printf( "plot.x_factor_union * f64( plot.size_x - 1 ) : %v\n\n", plot.x_factor_union * f64( plot.size_x - 1 ) )

    // Plot y values.

    fmt.printf( "plot.y_min_union : %v\n",    plot.y_min_union)
    fmt.printf( "plot.y_max_union : %v\n",    plot.y_max_union)
    fmt.printf( "plot.y_range_union : %v\n",  plot.y_range_union)
    fmt.printf( "plot.y_factor_union : %v\n", plot.y_factor_union)
    fmt.printf( "plot.size_y : %v\n",         plot.size_y)
    fmt.printf( "plot.y_factor_union * f64( plot.size_y - 1 ) : %v\n\n", plot.y_factor_union * f64( plot.size_y - 1 ) )
}


// Draw the N plot, the axies, the numbers and the legend.
plot_draw :: proc ( plot: ^Plot ) {

    // plot := plot

    // Fuses all plots into one x-range set
    plot_xx_fusion( plot )

    // Fuses all plots into one y-range set
    plot_yy_fusion( plot )

    // Draw's all the plots.
    for i in 0 ..< len( plot.plot_instances ) {
        plot_inst := plot.plot_instances[ i ]

        // If scatter plot, then plot the pints off all points.
        if plot.type == PlotType.Scatter {  
            
            for i in 0 ..< len( plot_inst.point_tuple_array.x_vec ) {

                // Get the x and y values of the point.
                func_x_pos := plot_inst.point_tuple_array.x_vec[ i ]
                func_y_pos := plot_inst.point_tuple_array.y_vec[ i ]

                x_img_pos, y_img_pos := convert_xy_funct_pos_to_xy_img_pos( plot, func_x_pos, func_y_pos )

                // Plots cross point.
                plot_point( plot_inst.trace_size_point_n, plot, x_img_pos, y_img_pos, plot_inst.p_color )                        
            }
        }

        // If lines plot, then plot the pints off all traces.
        if plot.type == PlotType.Line {  
        
            // Scale y-values to plot size and plot them.
            // for i in 0 ..< len( plot_inst.y_values_vec ) {
            for i in 0 ..< plot.size_x {
        
                // Don't plot the points that don't exist for that plot instance or plot line.
                if !plot_inst.xx_values_that_exist_vec[ i ] {
                    continue
                }

                // don't plot the point if it's is a point that should not be ploted, like infinit in a tan( x ).
                if plot_inst.y_values_vec[ i ] == POINT_NOT_DEFINED_YY {
                    continue
                }

                x := plot.x_values_vec[ i ]

                y_tmp := abs( plot.y_min_union - plot_inst.y_values_vec[ i ] ) * f64( plot.size_y )
                y_tmp = y_tmp / abs( plot.y_min_union - plot.y_max_union )
                y := plot.size_y - int( y_tmp )

                // Plots cross point.
                plot_point( plot_inst.trace_size_point_n, /*  PointN.P_3, */ plot, i, y, plot_inst.p_color )                        
        
            }

        }        
    }

    // Draw xx-axies y=0.

    Type_Y_Range :: enum {
        Zero_Between_Min_Max,
        Zero_Less_Than_Min,
        Zero_Greater_Than_Max,
    }

    type_y_range := Type_Y_Range.Zero_Between_Min_Max
    
    // Calculate the index_y0 were in image pixel coordenates is the y0 axis.
    index_y0 : f64 = 0
    // Correct the value of the index_y0_tmp of the axies for the 3 cases.
    index_y0_tmp : f64 = 0
    if 0 >= plot.y_min_union && 0 <= plot.y_max_union {
        index_y0 = ( f64( plot.size_y - 1 ) - ( 0 - plot.y_min_union ) * plot.y_factor_union * f64( plot.size_y - 1 ) )
        type_y_range = Type_Y_Range.Zero_Between_Min_Max
        index_y0_tmp = index_y0
    } else if 0 < plot.y_min_union {
        // index_y0 = 0
        index_y0 = ( ( 0 + plot.y_min_union + plot.y_range_union / 2 ) * plot.y_factor_union * f64( plot.size_y - 1 ) )
        type_y_range = Type_Y_Range.Zero_Less_Than_Min
        index_y0_tmp = f64( plot.size_y - 1 )
    } else if 0 > plot.y_max_union {
        index_y0 = ( 0 - plot.y_max_union - plot.y_range_union / 2 ) * plot.y_factor_union * f64( plot.size_y - 1 )
        type_y_range = Type_Y_Range.Zero_Greater_Than_Max
        index_y0_tmp = f64( 0 )
    }

    // Number of number on the xx-axies.
    xx_num_number_tags : int = 10

    index_x0 := plot.index_x0 

    if plot.index_x0 < 0 {
        // Draw the vertical line on the left side of the image.
        index_x0 = 0
    } else if plot.index_x0 > plot.size_x - 1 {
        // Draw the vertical line on the right side of the image.
        index_x0 = plot.size_x - 1
    }

    // Debug.
    // print_plot_struct( plot, index_x0, index_y0 )

    x_accu := 0
    for i in 0 ..< plot.size_x {
    
        plot_point( PointN.P_3, plot, i, int( index_y0_tmp ), color.gray )

        // Plot marks above and below x-axis 11 marks.
        if abs( i - plot.index_x0) % int( ( plot.size_x / xx_num_number_tags ) ) == 0 {
            plot_point( PointN.P_7, plot, i, int( index_y0_tmp ), color.gray )
            
            // AQUI
            // x_value := plot.x_values_vec[ i ]
            
            // Calculate the image x-value to plot x-value of the function.
            x_value := convert_from_img_x_pos_to_funct_x_pos( plot, i )

            // text    := fmt.aprintf( "%.2v", f64( 1234 ) )
            text : string
            if x_accu == xx_num_number_tags - 1 {
                // Write the the units on the last tag the 11 th tag.
                text = fmt.aprintf( "%.3v %v", f64( x_value ), plot.xx_units )
            } else {
                // Don't write the units on the other tags, including the zero
                // that will be changed bellow.
                text = fmt.aprintf( "%.3v", f64( x_value ) )
            }
            defer delete( text )

            delta_x := -5 * f64( len( text )) / 2 
            delta_y := 6.0
            flag_zero := false

            if type_y_range == Type_Y_Range.Zero_Less_Than_Min || 
               ( index_y0_tmp > f64( plot.size_y - 22 ) &&   // 20 is some what the size of the text.
                 index_y0_tmp < f64( plot.size_y ) ) {
                delta_y = -12.0
            }

            if i == plot.index_x0 {
                if type_y_range == Type_Y_Range.Zero_Between_Min_Max {
                    // Write the text "0", in the certer of the axies.
                    flag_zero = true
                    // text_1  := "0"
                    if plot.index_x0 < 10 {
                        // Draw the number on the right side of the xx_axies.
                        delta_x = 10 // +6.3 * f64( len( text ) )    
                    } else {
                        // Draw the number on the left side of the xx_axies.
                        delta_x = -8
                    }
                    delta_y =  6
                } else if type_y_range != Type_Y_Range.Zero_Between_Min_Max { 
                    x_accu += 1
                    continue
                }        
            }

            x := i + int( delta_x )
            y := int( index_y0_tmp + delta_y )
            scale : = f32( 1 )
            if flag_zero {
                plot_text( plot, "0", x, y, plot.digits_color, scale )
            } else {
                plot_text( plot, text, x, y, plot.digits_color, scale )

            }
            x_accu += 1
        }
    }

    racio_y_over_x := f64( plot.size_y ) / f64( plot.size_x )

    yy_num_number_tags := racio_y_over_x * f64( xx_num_number_tags )  

    // Draw yy-axies x=0.
    y_accu := 0
    for j in 0 ..< plot.size_y {
        plot_point( PointN.P_3, plot, index_x0, j, color.gray )

        // Plot marks to the left and to the right y-axis 11 marks.
        if abs( j - int( index_y0 ) ) % int( ( f64( plot.size_y ) / yy_num_number_tags ) ) == 0 {
            plot_point( PointN.P_7, plot, index_x0, j, color.gray )

            // AQUI
            // Calculate the image y-value to plot y-value of the function.
            // yy_step := plot.y_range_union / f64( plot.size_y - 1 )
            // y_value := plot.y_min_union + yy_step * f64( plot.size_y - j )
            
            // Calculate the image y-value to plot y-value of the function.
            y_value := convert_from_img_y_pos_to_funct_y_pos( plot, j )

            text    := fmt.aprintf( "%.3v", f64( y_value ) )
            // text := fmt.aprintf( "%.2v", f64( 1234 ) )
            defer delete( text )

            delta_x : f64
            if plot.index_x0 < 10 {
                // Draw the number on the right side of the yy_axies.
                delta_x = 10 // +6.3 * f64( len( text ) )    
            } else {
                // Draw the number on the left side of the yy_axies.
                delta_x = -6.3 * f64( len( text ) ) 
            }
            delta_y := -1.5 // 2.0
            if abs( j - int( index_y0_tmp ) ) <= 1 {

                // Write the text "0", in the center of the axies.
                y_accu += 1
                continue
            }

            // x := int( f64( plot.index_x0 ) + delta_x )
            x := int( f64( index_x0 ) + delta_x ) 
            y := j + int( delta_y )
            scale : = f32( 1 )
            plot_text( plot, text, x, y, plot.digits_color, scale )

            y_accu += 1
        }

        // Write the yy_units on top in the first iteration.
        if j == 0 {
            // Write the text "0", in the certer of the axies.
            text_1  := plot.yy_units
            delta_x : f64
            if plot.index_x0 < 10 {
                // Draw the number on the right side of the yy_axies.
                delta_x = 10 // +6.3 * f64( len( text ) )    
            } else {
                // Draw the number on the left side of the yy_axies.
                delta_x = -6.3 * f64( len( text_1 ) ) 
            }
            delta_y := 10
            x := int( f64( index_x0 ) + delta_x ) 
            y := j + int( delta_y )
            scale : = f32( 1 )
            plot_text( plot, text_1, x, y, plot.digits_color, scale )
        }
        
    }

    // Draw legends of the N plots.
    for i in 0 ..< len( plot.plot_instances ) {
        plot_instance := plot.plot_instances[ i ]

        x := plot_instance.legend_pos[ 0 ] 
        y := plot_instance.legend_pos[ 1 ]
        scale : = f32( 1.6 )
        plot_text( plot,
                   plot_instance.legend,
                   x,
                   y,
                   plot_instance.p_color,
                   scale )
    }

}

Point_Vec :: struct {
    x_vec : []f64,
    y_vec : []f64,
}

// func_pos : can be a x coordenate, or a y coordenate.
convert_funct_pos_to_img_pos :: proc ( func_pos : f64, func_pos_min: f64, func_pos_max: f64, img_size_in_coordenate: int ) -> 
                                     ( img_pos : int ) {
    
    img_pos_f64 := ( ( func_pos - func_pos_min ) / ( func_pos_max - func_pos_min ) ) * f64( img_size_in_coordenate )
    img_pos      = int( img_pos_f64 )
    return img_pos
}

// Only used for scattering plots.
// To convert the x and y function positions to image positions.
convert_xy_funct_pos_to_xy_img_pos :: proc ( plot : ^Plot, func_x_pos, func_y_pos : f64 ) ->
                                      ( x_img_pos : int, y_img_pos : int ) {
    
    x_pos_min: f64 = plot.x_min_union
    x_pos_max: f64 = plot.x_max_union
    y_pos_min: f64 = plot.y_min_union
    y_pos_max: f64 = plot.y_max_union

    size_x : int = plot.size_x 
    size_y : int = plot.size_y
    
    x_img_pos = convert_funct_pos_to_img_pos( func_x_pos,
                                              x_pos_min,
                                              x_pos_max, 
                                              size_x )
    
    y_img_pos = convert_funct_pos_to_img_pos( func_y_pos,
                                              y_pos_min,
                                              y_pos_max,
                                              size_y )
    
    y_img_pos = size_y - y_img_pos
    
    return x_img_pos, y_img_pos
}

// Convert the image x-value to plot x-value of the function.
convert_from_img_x_pos_to_funct_x_pos :: proc ( plot : ^Plot, img_x_pos : int ) -> ( func_x_pos : f64 ) {

    xx_step := plot.x_range_union / f64( plot.size_x - 1 ) 
    x_value := plot.x_min_union + xx_step * f64( /* plot.size_x - */ img_x_pos )

    func_x_pos = x_value
    return func_x_pos
}

// Convert the image y-value to plot y-value of the function.
convert_from_img_y_pos_to_funct_y_pos :: proc ( plot : ^Plot, img_y_pos : int ) -> ( func_y_pos : f64 ) {

    yy_step := plot.y_range_union / f64( plot.size_y - 1 )
    y_value := plot.y_min_union + yy_step * f64( plot.size_y - img_y_pos )

    func_y_pos = y_value
    return func_y_pos
}

plot_scatter :: proc ( plot               : ^Plot,
                       point_tuple_array  : ^Point_Vec,
                       legend             : string,
                       legend_pos         : [2]int,
                       p_color            : RGBA,
                       trace_size_point_n : PointN = PointN.P_3 ) {

    // Defines this trace type.
    trace_type : PlotType = PlotType.Scatter

    // xx_values_that_exist_vec : []bool
    
    // x_values_vec : []f64
    // index_x0     : int
    // x_step       : f64
    
    
    // Calculate:
    // - x_min and x_max of the plot instance.
    // - y_min and y_max of the plot instance.
    // - index_x0 were in image pixel coordenates is the x0 axis.
    // - index_y0 were in image pixel coordenates is the y0 axis.
    
    x_min, x_max : f64
    y_min, y_max : f64

    ok : bool
    x_min, x_max, ok = slice.min_max( point_tuple_array.x_vec )
    if !ok {
        panic( "Inside scatter slice.min_max() XX array failed" )
    }
    y_min, y_max, ok = slice.min_max( point_tuple_array.y_vec )
    if !ok {
        panic( "Inside scatter slice.min_max() YY array failed" )
    }


    // Calculate were in image pixel coordenates is the position of the x and y axies.

    // x_function_point -> image_x

    // y_function_point -> image_y

    // index_x0 := 0

    // Create the instance.
    plot_instance := PlotInstance{
        trace_type = trace_type,                // PlotType.Scatter
        xx         = [2]f64{-1, 1},             // Dummy value - Not used in a scatter plot.
        yy         = nil,                       // Not used in a scatter plot.

        point_tuple_array = point_tuple_array,  // Scatter array of points

        legend                   = legend,
        legend_pos               = legend_pos,
        p_color                  = p_color,
        trace_size_point_n       = trace_size_point_n,
        xx_values_that_exist_vec = nil,         // Not used in a scatter plot.
        y_values_vec             = nil,         // Not used in a scatter plot.
        y_min                    = y_min,
        y_max                    = y_max,
        x_min                    = x_min,
        x_max                    = x_max,
    }

    // Add the instance to the Vector of instances.
    append( & plot.plot_instances, plot_instance )
}

plot_histogram :: proc ( plot: ^Plot, xx : []f64, yy : []f64 , legend : string, color : RGBA ) {

}

plot_text :: proc ( plot: ^Plot, text : string, x : int, y : int, color : RGBA, scale : f32 ) {
    // plot := plot

    if x < 0 || x >= plot.size_x || y < 0 || y >= plot.size_y {
        return
    }

    quads: [200]easy_font.Quad = ---

	c := transmute(easy_font.Color)( color )
	// num_quads := easy_font.print(10, 60, text, c, quads[:], scale )
    num_quads := easy_font.print( f32( x ), f32( y ), text, c, quads[:], scale )

    // Draw quads
    for i in 0 ..< num_quads {
        quad := quads[i]
        // Draw the vextexs rectangules to the plot buffer.
        for j in quad.tl.v.y ..< ( quad.tl.v.y + quad.br.v.y - quad.tl.v.y ) {
            for i in quad.tl.v.x ..< ( quad.tl.v.x + quad.br.v.x - quad.tl.v.x ) {

                if i < 0 || i >= f32( plot.size_x ) || j < 0 || j >= f32( plot.size_y ) {
                    continue
                }           
                index := get_1d_pos_from_xy( int( i ), int( j ), plot.size_x, plot.size_y, invert_y = false )
                plot.img_buffer[ index ] = Pixel{ val_RGBA = color }
                // fmt.println( "i : %v", i, "    j : %v \n", j )
            }
        }
        // r := rl.Rectangle{x = tl.x, y = tl.y, width = br.x - tl.x, height = br.y - tl.y}
    }

}

plot_save :: proc ( plot: ^Plot, file_path : string ) {

    // Draw the N plot, the axies, the numbers and the legend.
    plot_draw( plot )

    // 4 components: RGBA
    type_of_components : i32 = 4
    // stride is in bytes.
    stride := i32( plot.size_x * size_of( Pixel ) )

    png.write_png( 
        strings.clone_to_cstring( file_path ),
        i32( plot.size_x ),
        i32( plot.size_y ),
        type_of_components,
        rawptr( & plot.img_buffer[ 0 ] ),  // &data[0],
        stride )
}

// Note: If you whant to integrate the plot in your own window, you can use
//       this function to get the image buffer.
//       But before calling this function you must call the function 
//       plots.plot_draw( plot ) .
//       To get a rawptr to the image buffer inside your function, do:
//          rawptr( & image_buffer[ 0 ] ) .
plot_get_image_buffer :: proc ( plot: ^Plot ) -> 
            ( image_buffer : [dynamic]Pixel, size_x : int, size_y : int ) {
    image_buffer = plot.img_buffer
    size_x = plot.size_x
    size_y = plot.size_y
    return image_buffer, size_x, size_y
}

