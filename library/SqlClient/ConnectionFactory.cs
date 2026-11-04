using System;
using System.Data.Common;
using System.Reflection;
using System.Runtime.Loader;

namespace D365Bap.Tools.SqlClient
{
    public static class ConnectionFactory
    {
        private static readonly Lazy<DbProviderFactory> Provider = new(() =>
        {
            var context = new SqlClientLoadContext(typeof(ConnectionFactory).Assembly.Location);
            var assembly = context.LoadFromAssemblyName(new AssemblyName("Microsoft.Data.SqlClient"));
            var factory = assembly.GetType("Microsoft.Data.SqlClient.SqlClientFactory", throwOnError: true)!;
            return (DbProviderFactory)factory.GetField("Instance")!.GetValue(null)!;
        });

        public static DbProviderFactory Instance => Provider.Value;

        private sealed class SqlClientLoadContext : AssemblyLoadContext
        {
            private readonly AssemblyDependencyResolver resolver;

            public SqlClientLoadContext(string path) : base("d365bap.tools.SqlClient")
            {
                resolver = new AssemblyDependencyResolver(path);
            }

            protected override Assembly? Load(AssemblyName name)
            {
                var path = resolver.ResolveAssemblyToPath(name);
                return path == null ? null : LoadFromAssemblyPath(path);
            }

            protected override IntPtr LoadUnmanagedDll(string name)
            {
                var path = resolver.ResolveUnmanagedDllToPath(name);
                return path == null ? IntPtr.Zero : LoadUnmanagedDllFromPath(path);
            }
        }
    }
}
