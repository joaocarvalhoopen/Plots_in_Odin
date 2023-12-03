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

package main

import "./plots"
import "core:fmt"
import "core:math"


// ############
// Line plots. 

// Makes a line plot with one trace.
// Plots the function sin( x ) in the range -10 -> 4.
// The function can be what ever you like. In a Custom function,
// not represented points, that should not appear should be marked
// with POINT_NOT_DEFINED_YY.
// The plot is saved in a png file with custom size 800 x 600.
// The plot is created with a white background and dark digits.
// The plot is created with a blue trace.
// The plot is created with a legend with a custom position.
// The plot has a title with a custom position.
// The plit has a manually added point with a custom color.
// The plot has a manually added text label with a custom color.
p01_line_1_trace_white :: proc () {
    fmt.println( "p01_line_1_trace_white() \n" )
    
    // Plot png image file path.
    file_path := "./images/p01_line_1_trace_white.png"

    // Plot image size.
    size_x := 800
    size_y := 600
    // xx range.
    xx := [2]f64{ -10, 4 }
    
    // yy function.
    yy_1 :: proc ( x : f64 ) -> f64 {
        return math.sin_f64( x )
    }

    // Create plot.
    p := plots.plot_create( plots.PlotType.Line, size_x, size_y,
                            background_color=plots.color.white,
                            digits_color=plots.color.gray_dark,
                            xx_units="( sec )",
                            yy_units="( m )" )
    
    // Add one trace to the plot, N can be added in sequence.
    // The trace is a function of X and the XX range has to be the same.
    plots.plot_line( &p,
                     xx,
                     yy_1,
                     nil,
                     "1. sin( x )",
                     [2]int{ size_x - 150, size_y - 80 },
                     plots.color.blue )

    // Optionally, you can add text to the plot.
    plots.plot_text( &p, text="p01_line_1_trace_white()",
        x=20, y=20, color=plots.color.gray_dark, scale=1.8 )

    // Optionally, you can add manually a point mark to the plot in any color.
    plots.plot_point( plots.PointN.P_13, &p, x=254, y=100,
        p_color=plots.color.gray_dark )

    // Optionally, you can add a text label to the point.
    plots.plot_text( &p, text="Watch this point ->", 
        x=254 - 185, y=100 - 5, color=plots.color.red, scale=1.6 )

    plots.plot_save( &p, file_path )
    plots.plot_destroy( &p )
}

// The same as p01_line_1_trace_white() but with a dark background and light digits.
p02_line_1_trace_dark :: proc () {
    fmt.println( "p02_line_1_trace_dark() \n" )
    
    // Plot png image file path.
    file_path := "./images/p02_line_1_trace_dark.png"

    // Plot image size.
    size_x := 800
    size_y := 600
    // xx range.
    xx := [2]f64{ -10, 4 }
    
    // yy function.
    yy_1 :: proc ( x : f64 ) -> f64 {
        return math.sin_f64( x )
    }

    // Create plot.
    p := plots.plot_create( plots.PlotType.Line, size_x, size_y,
                            background_color=plots.color.black,
                            digits_color=plots.color.gray,
                            xx_units="( sec )",
                            yy_units="( m )" )
    
    // Add one trace to the plot, N can be added in sequence.
    // The trace is a function of X and the XX range has to be the same.
    plots.plot_line( &p,
                     xx,
                     yy_1,
                     nil,
                     "1. sin( x )",
                     [2]int{ size_x - 150, size_y - 80 },
                     plots.color.blue )

    // Optionally, you can add text to the plot.
    plots.plot_text( &p, text="p02_line_1_trace_dark()", x=20, y=20, color=plots.color.gray, scale=1.8 )

    // Optionally, you can add manually a point mark to the plot in any color.
    plots.plot_point( plots.PointN.P_13, &p, x=254, y=100, p_color=plots.color.gray )

    // Optionally, you can add a text label to the point.
    plots.plot_text( &p, text="Watch this point ->", x=254 - 185, y=100 - 5, color=plots.color.red, scale=1.6 )

    plots.plot_save( &p, file_path )
    plots.plot_destroy( &p )
}

// Makes a line plot with four traces.
// Plots the functions sin( x ) + 3, cos( x ) - 3, 1 and tan( x ).
// The functions XX range has to be the same.
// The function YY range are fused can be specified or automatically detected.
// The functions can be what ever you like. In a Custom function,
// not represented points, that should not appear should be marked
// with POINT_NOT_DEFINED_YY.
p03_line_4_traces :: proc () {
    fmt.println( "p03_line_4_traces() \n" )
    
    // Plot png image file path.
    file_path := "./images/p03_line_4_traces.png"

    // Plot image size.
    size_x := 800
    size_y := 600
    // xx range.
    xx := [2]f64{ -2 * math.PI , 2 * math.PI}
    // xx := [2]f64{ 2 , 4 }         // Correct.
    // xx := [2]f64{ -4 , -2 }       // Correct. 
    // xx := [2]f64{ -3 , 4 }        // Correct.

    // yy function.
    yy_1 :: proc ( x : f64 ) -> f64 {
        return math.sin_f64( x ) + 3
    }

    yy_2 :: proc ( x : f64 ) -> f64 {
        return math.cos_f64( x ) - 3
    }

    yy_3 :: proc ( x : f64 ) -> f64 {
        return 1
    }

    yy_4 :: proc ( x : f64 ) -> f64 {
        return math.tan_f64( x )
    }

    // Create plot.
    p := plots.plot_create( plots.PlotType.Line, size_x, size_y,
                            background_color=plots.color.white,
                            digits_color=plots.color.gray_dark,
                            xx_units="( sec )",
                            yy_units="( m )" )
    
    // Add any number of traces to the plot, N can be added in sequence.
    // The trace is a function of X and the XX range has to be the same.
    plots.plot_line( plot=&p,
                     xx_p=xx,
                     yy=yy_1,
                     yy_limits=nil,
                     legend="1. sin ( x ) + 3",
                     legend_pos=[2]int{ size_x - 150, size_y - 120 },
                     p_color=plots.color.blue )

    plots.plot_line( plot=&p,
                     xx_p=xx,
                     yy=yy_2,
                     yy_limits=nil,
                     legend="2. cos ( x ) - 3",
                     legend_pos=[2]int{ size_x - 150, size_y - 90 },
                     p_color=plots.color.red )
   

    plots.plot_line( plot=&p,
                     xx_p=xx,
                     yy=yy_3,
                     yy_limits=nil,
                     legend="3. y = 1",
                     legend_pos=[2]int{ size_x - 150, size_y - 60 },
                     p_color=plots.color.green )
       
    plots.plot_line( plot=&p,
                     xx_p=xx,
                     yy=yy_4,
                     yy_limits=&[2]f64{ -10, 10 },  // The user can impose limits on the YY axis values.
                     legend="4. tan ( x )",
                     legend_pos=[2]int{ size_x - 150, size_y - 30 },
                     p_color=plots.color.gray_dark )
    
    // Optionally, you can add text to the plot.
    plots.plot_text( &p, text="p03_line_4_traces()", x=20, y=20, color=plots.color.gray_dark, scale=1.8 )

    // Optionally, you can add manually a point mark to the plot in any color.
    // plots.plot_point( plots.PointN.P_13, &p, x=254, y=100, p_color=plots.color.gray )

    // Optionally, you can add a text label to the point.
    // plots.plot_text( &p, text="Watch this point ->", x=254 - 185, y=100 - 5, color=plots.color.red, scale=1.6 )

    plots.plot_save( &p, file_path )
    plots.plot_destroy( &p )
}

// The function tan( x ) is not defined in some pois of the range -4 -> 4,
// the previous functions showed the function with specified -y_limit and +y_limit,
// but this plot line example uses automatic limits detection.
p04_line_1_traces_no_limits :: proc () {
    fmt.println( "p04_line_1_traces_no_limits() \n" )
    
    // Plot png image file path.
    file_path := "./images/p04_line_1_traces_no_limits.png"

    // Plot image size.
    size_x := 800
    size_y := 600
    // xx range.
    xx := [2]f64{ -4, 4 }
    
    // yy function.
    yy_1 :: proc ( x : f64 ) -> f64 {
        return math.tan_f64( x )
    }

    // Create plot.
    p := plots.plot_create( plots.PlotType.Line, size_x, size_y,
                            background_color=plots.color.white,
                            digits_color=plots.color.gray_dark,
                            xx_units="( sec )",
                            yy_units="( m )" )
    
    // Add one trace to the plot, N can be added in sequence.
    // The trace is a function of X and the XX range has to be the same.
    plots.plot_line( plot=&p,
                     xx_p=xx,
                     yy=yy_1,
                     yy_limits=nil,
                     legend="1. tan( x )",
                     legend_pos=[2]int{ size_x - 150, size_y - 80 },
                     p_color=plots.color.blue )

    // Optionally, you can add text to the plot.
    plots.plot_text( &p, text="p04_line_1_traces_no_limits( )", x=20, y=20, color=plots.color.gray, scale=1.8 )

    plots.plot_save( &p, file_path )
    plots.plot_destroy( &p )
}

// This plots the function y = x but only for a set of sepcified points.
p05_line_1_array_of_xx_values :: proc () {
    fmt.println( "p05_line_1_array_of_xx_values() \n" )
    
    // Plot png image file path.
    file_path := "./images/p05_line_1_array_of_xx_values.png"

    // Plot image size.
    size_x := 800
    size_y := 600
    // xx range.
    xx := []f64{ -10, -9, -8, -7, -6, -5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
    
    // yy function.
    yy_1 :: proc ( x : f64 ) -> f64 {
        return x
    }

    // Create plot.
    p := plots.plot_create( plots.PlotType.Line, size_x, size_y,
                            background_color=plots.color.white,
                            digits_color=plots.color.gray_dark,
                            xx_units="( sec )",
                            yy_units="( m )" )
    
    // Add one trace to the plot, N can be added in sequence.
    // The trace is a function of X and the XX range has to be the same.
    plots.plot_line( plot=&p,
                     xx_p=xx,
                     yy=yy_1,
                     yy_limits=nil,
                     legend="1. y = x",
                     legend_pos=[2]int{ size_x - 150, size_y - 80 },
                     p_color=plots.color.blue,
                     trace_size_point_n=plots.PointN.P_13 )

    // Optionally, you can add text to the plot.
    plots.plot_text( &p, text="p05_line_1_array_of_xx_values()", x=20, y=20, color=plots.color.gray, scale=1.8 )

    plots.plot_save( &p, file_path )
    plots.plot_destroy( &p )
}



// ################
// Scatters plots.

// This plots a scatter plot of the funtion y = abs( x ) specified as two
// slices of points, one for X values and one for Y values.
// The scatter plot doesn't need to have only at most point of Y for a each
// point of X.
// It can have multiple Y points for each X point.
p10_scatter_from_1_points_array :: proc () {
    fmt.println( "p10_scatter_from_1_points_array() \n" )
    
    // Plot png image file path.
    file_path := "./images/p10_scatter_from_1_points_array.png"

    // Plot image size.
    size_x := 800
    size_y := 600
    // xx coordenate of points.
    // -10 -> 10
    xx := []f64{ -10, -9, -8, -7, -6, -5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
    // yy coordenate of points.
    // 0 -> 10
    yy := []f64{  10,  9,  8,  7,  6,  5,  4,  3,  2,  1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }

    // Create point array.
    point_tuple_array := new( plots.Point_Vec )
    defer free( point_tuple_array )

    // Fill point coordenates with slices.
    point_tuple_array.x_vec = xx    // X values.
    point_tuple_array.y_vec = yy    // Y values.

    // Create plot.
    p := plots.plot_create( plots.PlotType.Scatter, size_x, size_y,
                            background_color=plots.color.white,
                            digits_color=plots.color.gray_dark,
                            xx_units="( sec )",
                            yy_units="( m )" )
    
    // Add one scatter points to the plot, N can be added in sequence.
    plots.plot_scatter( plot               = &p,
                        point_tuple_array  = point_tuple_array,
                        legend             = "1. Points array",
                        legend_pos         = [2]int{ size_x - 150, size_y - 80 },
                        p_color            = plots.color.blue,
                        trace_size_point_n = plots.PointN.P_17 )

    // Optionally, you can add text to the plot.
    plots.plot_text( &p, text="p10_scatter_from_1_points_array( )", x=20, y=20, color=plots.color.gray, scale=1.8 )

    plots.plot_save( &p, file_path )
    plots.plot_destroy( &p )
}

// This plots a scatter plot specified as two set's of points.
// Each set of points is specified as two slices of a coordenate of p,
// one for X values and and the other with Y values.
p11_scatter_from_2_points_array :: proc () {
    fmt.println( "p11_scatter_from_2_points_array() \n" )
    
    // Plot png image file path.
    file_path := "./images/p11_scatter_from_2_points_array.png"

    // Plot image size.
    size_x := 800
    size_y := 600
    // xx coordenate of points.
    // -10 -> 10
    xx_1 := []f64{ -10, 0, 10 }
    // yy coordenate of points.
    // 0 -> 10
    yy_1 := []f64{ 0, 5, 10 }

    // Create point array.
    point_tuple_array_1 := new( plots.Point_Vec )
    defer free( point_tuple_array_1 )

    // Fill point coordenates with slices.
    point_tuple_array_1.x_vec = xx_1    // X values.
    point_tuple_array_1.y_vec = yy_1    // Y values.


    // -15 -> -12
    xx_2 := []f64{ -15, -14, -12 }
    // yy coordenate of points.
    // -10 -> -5
    yy_2 := []f64{ -5, -8, -10 }


    // Create point array.
    point_tuple_array_2 := new( plots.Point_Vec )
    defer free( point_tuple_array_2 )

    // Fill point coordenates with slices.
    point_tuple_array_2.x_vec = xx_2    // X values.
    point_tuple_array_2.y_vec = yy_2    // Y values.


    // Create plot.
    p := plots.plot_create( plots.PlotType.Scatter, size_x, size_y,
                            background_color=plots.color.white,
                            digits_color=plots.color.gray_dark,
                            xx_units="( sec )",
                            yy_units="( m )" )
    
    // Add first scatter points to the plot, N can be added in sequence.
    plots.plot_scatter( plot               = &p,
                        point_tuple_array  = point_tuple_array_1,
                        legend             = "1. A pts array",
                        legend_pos         = [2]int{ size_x - 150, size_y - 60 },
                        p_color            = plots.color.blue,
                        trace_size_point_n = plots.PointN.P_17 )

    // Add second scatter points to the plot, N can be added in sequence.
    plots.plot_scatter( plot               = &p,
                        point_tuple_array  = point_tuple_array_2,
                        legend             = "2. B pts array",
                        legend_pos         = [2]int{ size_x - 150, size_y - 30 },
                        p_color            = plots.color.gray_dark,
                        trace_size_point_n = plots.PointN.P_17 )


    // Optionally, you can add text to the plot.
    plots.plot_text( &p, text="p11_scatter_from_2_points_array( )", x=20, y=20, color=plots.color.gray, scale=1.8 )

    plots.plot_save( &p, file_path )
    plots.plot_destroy( &p )
}


main :: proc () {
    fmt.printf( "Plots_in_Odin begin ...\n")


    // ############
    // Line plots. 

    p01_line_1_trace_white( )

    p02_line_1_trace_dark( )

    p03_line_4_traces( )

    p04_line_1_traces_no_limits( )

    p05_line_1_array_of_xx_values( )


    // ################
    // Scatters plots.

    p10_scatter_from_1_points_array( )

    p11_scatter_from_2_points_array( )


    fmt.printf( "...end Plots_in_Odin.\n")
}
