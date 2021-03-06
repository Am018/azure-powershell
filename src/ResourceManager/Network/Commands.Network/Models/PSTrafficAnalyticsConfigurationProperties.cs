// <auto-generated>
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for
// license information.
//
// Code generated by Microsoft (R) AutoRest Code Generator.
// Changes may cause incorrect behavior and will be lost if the code is
// regenerated.
// </auto-generated>

namespace Microsoft.Azure.Commands.Network.Models
{
    using Microsoft.Rest;
    using Newtonsoft.Json;
    using System.Linq;

    /// <summary>
    /// Parameters that define the configuration of traffic analytics.
    /// </summary>
    public partial class PSTrafficAnalyticsConfigurationProperties
    {
       
        /// <summary>
        /// Gets or sets flag to enable/disable traffic analytics.
        /// </summary>
        [JsonProperty(PropertyName = "enabled")]
        public bool Enabled { get; set; }

        /// <summary>
        /// Gets or sets the resource guid of the attached workspace
        /// </summary>
        [JsonProperty(PropertyName = "workspaceId")]
        public string WorkspaceId { get; set; }

        /// <summary>
        /// Gets or sets the location of the attached workspace
        /// </summary>
        [JsonProperty(PropertyName = "workspaceRegion")]
        public string WorkspaceRegion { get; set; }

        /// <summary>
        /// Gets or sets resource Id of the attached workspace
        /// </summary>
        [JsonProperty(PropertyName = "workspaceResourceId")]
        public string WorkspaceResourceId { get; set; }

        /// <summary>
        /// Validate the object.
        /// </summary>
        /// <exception cref="ValidationException">
        /// Thrown if validation fails
        /// </exception>
        public virtual void Validate()
        {
            if (WorkspaceId == null)
            {
                throw new ValidationException(ValidationRules.CannotBeNull, "WorkspaceId");
            }
            if (WorkspaceRegion == null)
            {
                throw new ValidationException(ValidationRules.CannotBeNull, "WorkspaceRegion");
            }
            if (WorkspaceResourceId == null)
            {
                throw new ValidationException(ValidationRules.CannotBeNull, "WorkspaceResourceId");
            }
        }
    }
}
