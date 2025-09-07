using System;

namespace YjsCrdtSharp.Extensions
{
    /// <summary>
    /// Extension methods for GUID generation compatible with Dart implementation
    /// </summary>
    public static class GuidExtensions
    {
        private static readonly Random _random = new Random();

        /// <summary>
        /// Generate a GUID v4 string compatible with Dart generateGuidV4() function
        /// </summary>
        public static string GenerateGuidV4()
        {
            return Guid.NewGuid().ToString();
        }

        /// <summary>
        /// Create a secure random GUID using cryptographic random number generation
        /// </summary>
        public static string GenerateSecureGuidV4()
        {
            var bytes = new byte[16];
            using (var rng = System.Security.Cryptography.RandomNumberGenerator.Create())
            {
                rng.GetBytes(bytes);
            }

            // Set version to 4
            bytes[6] = (byte)((bytes[6] & 0x0F) | 0x40);
            // Set variant bits
            bytes[8] = (byte)((bytes[8] & 0x3F) | 0x80);

            return new Guid(bytes).ToString();
        }
    }
}