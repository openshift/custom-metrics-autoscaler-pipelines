# The builder image is expected to contain
# /bin/opm (with serve subcommand)
#FROM quay.io/operator-framework/opm:latest as builder


# TODO(jkyros): if you don't use a version of opm that matches the registry server
# it will generate an incompatible database and it will complane that the "cache 
# directory has unexpected contents"
FROM registry.redhat.io/openshift4/ose-operator-registry:latest as builder
# Copy FBC root into image at /configs and pre-populate serve cache
ADD fbc /configs
RUN ["/bin/opm", "serve", "/configs", "--cache-dir=/tmp/cache", "--cache-only"]

FROM registry.redhat.io/openshift4/ose-operator-registry:latest
# The base image is expected to contain
# /bin/opm (with serve subcommand) and /bin/grpc_health_probe

# Configure the entrypoint and command
ENTRYPOINT ["/bin/opm"]
CMD ["serve", "/configs", "--cache-dir=/tmp/cache"]

COPY --from=builder /configs /configs
# TODO(jkyros): I'm getting 'cache directory has unexpected contents', god forbid it would say what it was
# the only thing in there is the pogreb database it generated. I'm assuming there is skew between the latest builder and 
# the runner image
COPY --from=builder /tmp/cache /tmp/cache

# Set FBC-specific label for the location of the FBC root directory
# in the image
LABEL operators.operatorframework.io.index.configs.v1=/configs
