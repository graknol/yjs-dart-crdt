using System;
using YjsCrdtSharp.Examples;

namespace YjsCrdtSharp.Examples
{
    /// <summary>
    /// Console application demonstrating Y.js CRDT Sharp library usage
    /// </summary>
    class Program
    {
        static void Main(string[] args)
        {
            Console.WriteLine("Y.js CRDT Sharp - C# Implementation Examples");
            Console.WriteLine("============================================");
            
            try
            {
                // Run basic example
                BasicExample.RunExample();
                
                // Run server-client example  
                ServerClientExample.RunExample();
                
                Console.WriteLine("\nPress any key to exit...");
                Console.ReadKey();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error running examples: {ex.Message}");
                Console.WriteLine($"Stack trace: {ex.StackTrace}");
            }
        }
    }
}