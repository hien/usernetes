FROM golang:latest
ADD https://github.com/bazelbuild/bazel/releases/download/0.15.2/bazel-0.15.2-linux-x86_64 /usr/local/bin/bazel
RUN chmod +x /usr/local/bin/bazel
ARG KUBERNETES_COMMIT
RUN echo KUBERNETES_COMMIT=${KUBERNETES_COMMIT}
RUN git clone https://github.com/kubernetes/kubernetes.git /kubernetes
WORKDIR /kubernetes
RUN git checkout ${KUBERNETES_COMMIT}
COPY ./patches/kubernetes /patches
# `git am` requires user info to be set
RUN git config user.email "nobody@example.com" && \
  git config user.name "Usernetes Build Script" && \
  git am /patches/* && git show --summary
