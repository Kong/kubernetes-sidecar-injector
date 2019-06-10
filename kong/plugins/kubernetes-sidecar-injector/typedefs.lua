local Schema = require "kong.db.schema"
local typedefs = require "kong.db.schema.typedefs"


local int32 = Schema.define { type = "integer", between = { -2147483648, 2147483647 } }

-- XXX: 9223372036854775807 gets rounded by lua < 5.3. Can we use LuaJIT long longs?
local int64 = Schema.define { type = "integer", between = { -9223372036854775808, 9223372036854775807 } }

-- represented in RFC3339 form and is in UTC
local Time = Schema.define { type = "string" }


--- Kubernetes Object definitions
-- These can be figured out via reading the kubernetes source.

-- https://github.com/kubernetes/kubernetes/blob/v1.13.1/staging/src/k8s.io/apimachinery/pkg/apis/meta/v1/types.go

local OwnerReference = Schema.define { type = "record", fields = {
  { apiVersion = { type = "string", required = true } },
  { kind = { type = "string", required = true } },
  { name = { type = "string", required = true } },
  { uid = typedefs.uuid { required = true } },
  { controller = { type = "boolean" } },
  { blockOwnerDeletion = { type = "boolean" } },
} }

local ListMeta = Schema.define { type = "record", fields = {
  { selfLink = { type = "string" } },
  { resourceVersion = { type = "string" } },
  { continue = { type = "string" } },
} }

local StatusReason = Schema.define { type = "string", len_min = 0, one_of = {
  "",
  "Unauthorized",
  "Forbidden",
  "NotFound",
  "AlreadyExists",
  "Conflict",
  "Gone",
  "Invalid",
  "ServerTimeout",
  "Timeout",
  "TooManyRequests",
  "BadRequest",
  "MethodNotAllowed",
  "NotAcceptable",
  "UnsupportedMediaType",
  "InternalError",
  "Expired",
  "ServiceUnavailable",
} }

local CauseType = Schema.define { type = "string", one_of = {
  "FieldValueNotFound",
  "FieldValueRequired",
  "FieldValueDuplicate",
  "FieldValueInvalid",
  "FieldValueNotSupported",
  "UnexpectedServerResponse",
} }

local StatusCause = Schema.define { type = "record", fields = {
  { reason = CauseType },
  { message = { type = "string" } },
  { field = { type = "string" } },
} }

local StatusDetails = Schema.define { type = "record", fields = {
  { name = { type = "string" } },
  { group = { type = "string" } },
  { kind = { type = "string" } },
  { uid = typedefs.uuid { } },
  { causes = { type = "array", elements = StatusCause } },
  { retryAfterSeconds = int32 },
} }

local Status = Schema.define { type = "record", fields = {
  { metadata = { type = ListMeta } },
  { status = { type = "string"  } },
  { message = { type = "string"  } },
  { reason = { type = StatusReason } },
  { details = { type = StatusDetails } },
  { code = int32 },
} }

local Initializer = Schema.define { type = "record", fields = {
  { name = { type = "string", required = true } },
} }

local Initializers = Schema.define { type = "record", fields = {
  { pending = { type = "array", required = true, elements = Initializer } },
  { status = Status { required = true } },
} }

local ObjectMeta = Schema.define { type = "record", fields = {
  { name = { type = "string" } },
  { generateName = { type = "string" } },
  { namespace = { type = "string" } },
  { selfLink = { type = "string" } },
  { uid = typedefs.uuid },
  { resourceVersion = { type = "string" } },
  { generation = int64 },
  { creationTimestamp = Time },
  { deletionTimestamp = Time },
  { deletionGracePeriodSeconds = { type = "integer" } },
  { labels = { type = "map", keys = { type = "string" }, values = { type = "string" } } },
  { annotations = { type = "map", keys = { type = "string" }, values = { type = "string" } } },
  { ownerReferences = { type = "array", elements = OwnerReference } },
  { initializers = Initializers },
  { finalizers = { type = "array", elements = { type = "string" } } },
  { clusterName = { type = "string" } },
} }


-- https://github.com/kubernetes/kubernetes/blob/v1.13.1/staging/src/k8s.io/apimachinery/pkg/runtime/types.go

local RawExtension = Schema.define { type = "any" }


-- https://github.com/kubernetes/kubernetes/blob/v1.13.1/staging/src/k8s.io/api/core/v1/types.go

local ImagePullPolicy = Schema.define { type = "string", one_of = {
  "Always",
  "Never",
  "IfNotPresent",
} }

-- TODO: Complete PodSpec definition
local PodSpec = Schema.define { type = "any" }

local Pod = Schema.define { type = "record", fields = {
  { metadata = ObjectMeta },
  { spec = PodSpec },
  { status = Status },
} }


-- https://github.com/kubernetes/kubernetes/blob/v1.13.1/staging/src/k8s.io/apimachinery/pkg/apis/meta/v1/group_version.go

local GroupVersionKind = Schema.define { type = "record", fields = {
  { group = { type = "string", required = true, len_min = 0 } },
  { version = { type = "string", required = true } },
  { kind = { type = "string", required = true } },
} }

local GroupVersionResource = Schema.define { type = "record", fields = {
  { group = { type = "string", required = true, len_min = 0 } },
  { version = { type = "string", required = true } },
  { resource = { type = "string", required = true } },
} }


-- https://github.com/kubernetes/kubernetes/blob/v1.13.1/staging/src/k8s.io/api/authentication/v1/types.go

local UserInfo = Schema.define { type = "record", fields = {
  { username = { type = "string" } },
  { uid = typedefs.uuid },
  { groups = { type = "array", elements = { type = "string" } } },
  -- TODO: kong map type doesn't allow 'null' as value
  -- { extra = { type = "map", keys = { type = "string" }, values = { type = "any" } } },
  { extra = { type = "any" } },
} }


-- https://github.com/kubernetes/kubernetes/blob/v1.13.1/staging/src/k8s.io/api/admission/v1beta1/types.go

local Operation = Schema.define { type = "string", one_of = {
  "CREATE",
  "UPDATE",
  "DELETE",
  "CONNECT",
} }

local AdmissionRequest = Schema.define {
  type = "record",
  fields = {
    { uid = typedefs.uuid { required = true } },
    { kind = GroupVersionKind { required = true } },
    { resource = GroupVersionResource { required = true } },
    { subResource = { type = "string" } },
    { name = { type = "string" } },
    { namespace = { type = "string" } },
    { operation = Operation { required = true } },
    { userInfo = UserInfo { required = true } },
    { object = RawExtension },
    { oldObject = RawExtension },
    { dryRun = { type = "boolean" } },
  },
  entity_checks = {
    { conditional = { if_field = "operation",
      if_match = { type = "string", one_of = { "UPDATE" } },
      then_field = "oldObject",
      then_match = { required = true },
      then_err = "oldObject required for UPDATEs",
    } },
  },
}


return {
  OwnerReference = OwnerReference,
  ListMeta = ListMeta,
  StatusReason = StatusReason,
  CauseType = CauseType,
  StatusCause = StatusCause,
  StatusDetails = StatusDetails,
  Status = Status,
  Initializer = Initializer,
  Initializers = Initializers,
  ObjectMeta = ObjectMeta,
  RawExtension = RawExtension,
  ImagePullPolicy = ImagePullPolicy,
  PodSpec = PodSpec,
  Pod = Pod,
  GroupVersionKind = GroupVersionKind,
  GroupVersionResource = GroupVersionResource,
  UserInfo = UserInfo,
  Operation = Operation,
  AdmissionRequest = AdmissionRequest,
}
