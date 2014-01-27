/* This is the WhoIsInTheHubb server application written in Go.
 * The server records nearby WiFi clients (using their MAC-addresses)
 * and stores statistics about them in a database.
 *
 * Will print the current clients on SIGUSR2
 * Will flush and update database of the current
 * known clients on SIGUSR1
 *
 * Copyright (C) 2013 Emil 'Eda' Edholm (digIT13)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
package main

import (
    "flag"
    "fmt"
    "github.com/golang/glog"
    "github.com/ogier/pflag"
    "os"
    "os/signal"
    "os/user"
    "strconv"
    "syscall"
    "time"
)

type Client struct {
    FirstSeen time.Time
    LastSeen  time.Time
    TimesSeen uint

    // TODO: Maybe record all timestamps?
}

var currClients = make(map[MAC]*Client)

// The command line flags available
var (
    // Log related flags
    logToStderr  = pflag.BoolP("logtostderr", "s", true, "log to stderr instead of to files")
    logThreshold = pflag.StringP("logthreshold", "t", "INFO", "Log events at or above this severity are logged to standard error as well as to files. Possible values: INFO, WARNING, ERROR and FATAL")
    logdir       = pflag.StringP("logpath", "l", "./logs", "The log files will be written in this directory/path")

    flushInterval = pflag.Int64P("flushinterval", "f", 283, "The flush interval in seconds")
    iface         = pflag.StringP("interface", "i", "mon0", "The capture interface to listen on")
    pcap          = pflag.StringP("pcap", "p", "", "Use a pcap file instead of live capturing")
)

func init() {
    pflag.Parse()

    // glog Logging options
    flag.Set("logtostderr", strconv.FormatBool(*logToStderr))
    flag.Set("log_dir", *logdir)
    flag.Set("stderrthreshold", *logThreshold)

    if isRoot() {
        glog.Warning("Server run with root privileges! This is uneccessary if tshark has been setup correctly")
    }
}

func main() {
    defer glog.Flush()

    if !InterfaceExists(*iface) && len(*pcap) == 0 {
        glog.Error(*iface + " interface does not exist")
        os.Exit(1)
    }

    glog.Info("Starting whoIsInTheHubb server")
    defer glog.Info("Shutting down whoIsInTheHubb server...")

    capchan := make(chan *CapturedFrame, 10)
    errchan := make(chan error)

    go func() {
        errchan <- StartTshark(CaptureFilter, capchan)
    }()

    go listenSIGUSR()
    go flushTimer()
    go listenForClients(capchan)
    err := <-errchan // Block until exit...
    if err == nil {
        glog.Info("tshark exited successfully")
        printClients()
    }
}

func listenForClients(capchan <-chan *CapturedFrame) {
    for frame := range capchan {
        if c, ok := currClients[frame.Mac]; !ok {
            currClients[frame.Mac] = &Client{frame.Timestamp, frame.Timestamp, 1}
        } else {
            // You seem familiar... Update LastSeen
            c.LastSeen = frame.Timestamp
            c.TimesSeen += 1
        }
    }
}

// flush the clients after the user specified amount of seconds
func flushTimer() {
    duration := time.Duration(*flushInterval) * time.Second
    for {
        <-time.After(duration)
        flushClients()
    }
}

// Listen and handle SIGUSR1 and SIGUSR2.
// SIGUSR1 will flush clients and SIGUSR2 will print the clients
// seen since start or last flush to stdout.
func listenSIGUSR() {
    ch := make(chan os.Signal)
    signal.Notify(ch, syscall.SIGUSR1, syscall.SIGUSR2)
    for {
        signal := <-ch
        glog.Info("Caught signal: ", signal)

        switch signal {
        case syscall.SIGUSR1:
            flushClients()
            break
        case syscall.SIGUSR2:
            printClients()
            break
        }
    }
}

func printClients() {
    var count int
    for mac, c := range currClients {
        count++
        fmt.Printf("MAC %s {\n\tFirst seen: %v\n\tLast seen:  %v\n\tTimes seen: %d\n}\n", mac, c.FirstSeen, c.LastSeen, c.TimesSeen)

    }
    if count > 0 {
        fmt.Println("Total:", count, "clients")
    }
}

// returns true if run with root privileges, else false.
func isRoot() bool {
    user, err := user.Current()
    if err != nil {
        glog.Error(err.Error())
        return false
    }
    return user.Username == "root"
}

// Flush means that the amount of seconds seen for each client/mac will be calculated
// and stored in the database.
func flushClients() {
    glog.Info("Flushing current clients...")

    var count uint

    for mac, client := range currClients {
        count++
        // TODO Implement...
        _ = mac
        _ = client
    }

    glog.Info("Flush complete! ", count, " clients flushed.")
}
