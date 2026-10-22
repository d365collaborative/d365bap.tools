using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Kiota.Abstractions.Authentication;
using Microsoft.Kiota.Http.HttpClientLibrary;
using Microsoft.Kiota.Abstractions;
using Microsoft.Kiota.Abstractions.Serialization;
using Microsoft.Kiota.Serialization.Json;
using Microsoft.PowerPlatform.Management;

namespace D365Bap.Tools.PowerPlatformSdk
{
    public static class SdkClient
    {
        public static string Execute(string builderTypeName, string methodName,
            string environmentId, string apiVersion, IParsable body, string token, string requestUrl)
        {
            using (var adapter = CreateAdapter(token))
            {
                var builderType = typeof(ServiceClient).Assembly.GetType(builderTypeName, true);
                var paths = new Dictionary<string, object>
                {
                    ["baseurl"] = adapter.BaseUrl,
                    ["environmentId"] = environmentId,
                    ["api%2Dversion"] = apiVersion
                };
                object builder;
                if (string.IsNullOrEmpty(requestUrl))
                    builder = Activator.CreateInstance(builderType, paths, adapter);
                else
                {
                    if (!Uri.TryCreate(requestUrl, UriKind.Absolute, out var nextUri) ||
                        nextUri.Scheme != Uri.UriSchemeHttps ||
                        !string.Equals(nextUri.Host, new Uri(adapter.BaseUrl).Host, StringComparison.OrdinalIgnoreCase) ||
                        !nextUri.IsDefaultPort || !string.IsNullOrEmpty(nextUri.UserInfo))
                        throw new ArgumentException("The continuation URL must use the Power Platform API host over HTTPS.", nameof(requestUrl));
                    builder = Activator.CreateInstance(builderType, requestUrl, adapter);
                }
                var method = builderType.GetMethod(methodName);
                var arguments = new List<object>();
                foreach (var parameter in method.GetParameters())
                {
                    if (typeof(IParsable).IsAssignableFrom(parameter.ParameterType))
                        arguments.Add(body);
                    else if (parameter.ParameterType == typeof(CancellationToken))
                        arguments.Add(CancellationToken.None);
                    else if (parameter.HasDefaultValue)
                        arguments.Add(null);
                    else
                        throw new NotSupportedException("Unsupported SDK parameter: " + parameter.Name);
                }
                var task = (Task)method.Invoke(builder, arguments.ToArray());
                task.GetAwaiter().GetResult();
                var result = task.GetType().GetProperty("Result").GetValue(task);
                return result == null ? null : KiotaJsonSerializer.SerializeAsStringAsync((IParsable)result).GetAwaiter().GetResult();
            }
        }

        public static HttpClientRequestAdapter CreateAdapter(string token)
        {
            ApiClientBuilder.RegisterDefaultSerializer<JsonSerializationWriterFactory>();
            ApiClientBuilder.RegisterDefaultDeserializer<JsonParseNodeFactory>();
            return new HttpClientRequestAdapter(
                new BaseBearerTokenAuthenticationProvider(new AccessTokenProvider(token)))
            {
                BaseUrl = "https://api.powerplatform.com"
            };
        }

        private sealed class AccessTokenProvider : IAccessTokenProvider
        {
            private readonly string token;

            public AccessTokenProvider(string token)
            {
                this.token = token;
            }

            public AllowedHostsValidator AllowedHostsValidator { get; } =
                new AllowedHostsValidator(new[] { "api.powerplatform.com" });

            public Task<string> GetAuthorizationTokenAsync(Uri uri,
                Dictionary<string, object> additionalAuthenticationContext = null,
                CancellationToken cancellationToken = default)
            {
                if (!AllowedHostsValidator.IsUrlHostValid(uri))
                    throw new InvalidOperationException("The SDK request host is not allowed.");
                cancellationToken.ThrowIfCancellationRequested();
                return Task.FromResult(token);
            }
        }
    }
}
