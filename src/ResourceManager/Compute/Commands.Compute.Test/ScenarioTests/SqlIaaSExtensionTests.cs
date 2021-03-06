﻿using Microsoft.WindowsAzure.Commands.ScenarioTest;
using Xunit;

namespace Microsoft.Azure.Commands.Compute.Test.ScenarioTests
{
    public class SqlIaaSExtensionTests
    {
        ServiceManagemenet.Common.Models.XunitTracingInterceptor _logger;
        public SqlIaaSExtensionTests(Xunit.Abstractions.ITestOutputHelper output)
        {
            _logger = new ServiceManagemenet.Common.Models.XunitTracingInterceptor(output);
            ServiceManagemenet.Common.Models.XunitTracingInterceptor.AddToContext(_logger);
        }

#if NETSTANDARD
        [Fact(Skip = "Resources -> ResourceManager, needs re-recorded")]
        [Trait(Category.RunType, Category.DesktopOnly)]
#else
        [Fact]
#endif
        [Trait(Category.AcceptanceType, Category.CheckIn)]
        public void TestSqlIaaSExtension()
        {
            ComputeTestController.NewInstance.RunPsTest(_logger, "Test-SetAzureRmVMSqlServerExtension");
        }

#if NETSTANDARD
        [Fact(Skip = "Resources -> ResourceManager, needs re-recorded")]
        [Trait(Category.RunType, Category.DesktopOnly)]
#else
        [Fact]
#endif
        [Trait(Category.AcceptanceType, Category.CheckIn)]
        public void TestSqlIaaSAKVExtension()
        {
            ComputeTestController.NewInstance.RunPsTest(_logger, "Test-SetAzureRmVMSqlServerAKVExtension");
        }

#if NETSTANDARD
        [Fact(Skip = "Resources -> ResourceManager, needs re-recorded")]
        [Trait(Category.RunType, Category.DesktopOnly)]
#else
        [Fact]
#endif
        [Trait(Category.AcceptanceType, Category.CheckIn)]
        public void TestSqlIaaSExtensionWith2016Image()
        {
            ComputeTestController.NewInstance.RunPsTest(_logger, "Test-SetAzureRmVMSqlServerExtensionWith2016Image");
        }
    }
}
