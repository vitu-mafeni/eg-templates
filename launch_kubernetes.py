#!/opt/conda/bin/python
"""Launch on kubernetes."""
import argparse
import os
import sys
from typing import Dict, List
import urllib3
import yaml
from jinja2 import Environment, FileSystemLoader, select_autoescape
from kubernetes import client, config
from kubernetes.client.rest import ApiException

urllib3.disable_warnings()

KERNEL_POD_TEMPLATE_PATH = "kernel-pod.yaml.j2"

def generate_kernel_pod_yaml(keywords):
    j_env = Environment(
        loader=FileSystemLoader(os.path.dirname(__file__)),
        trim_blocks=True,
        lstrip_blocks=True,
        autoescape=select_autoescape(
            disabled_extensions=("j2", "yaml"),
            default_for_string=True,
            default=True,
        ),
    )
    return j_env.get_template(KERNEL_POD_TEMPLATE_PATH).render(**keywords)

def extend_pod_env(pod_def: dict) -> dict:
    """Merge KERNEL_* env vars from the launcher process into the pod spec.

    Only variables whose names start with ``KERNEL_`` are injected.  Dumping
    the full launcher environment (the previous behaviour) polluted the kernel
    pod with EG-server variables such as ``CUDA_VISIBLE_DEVICES`` and
    ``LD_PRELOAD``, which silently overrode the values that the HAMi mutating
    webhook injects after pod admission.
    """
    env_stanza = pod_def["spec"]["containers"][0].get("env") or []
    processed_entries: List[str] = []
    # Update any entry that is already present in the template stanza.
    for item in env_stanza:
        item_name = item.get("name")
        if item_name in os.environ:
            item["value"] = os.environ[item_name]
            processed_entries.append(item_name)
    # Append only KERNEL_* variables that were not already in the stanza.
    for name, value in os.environ.items():
        if name.startswith("KERNEL_") and name not in processed_entries:
            env_stanza.append({"name": name, "value": value})
    pod_def["spec"]["containers"][0]["env"] = env_stanza
    return pod_def

K8S_ALREADY_EXIST_REASON = "AlreadyExists"

def _parse_k8s_exception(exc: ApiException) -> str:
    msg = f'"reason":{K8S_ALREADY_EXIST_REASON}'
    if exc.status == 409 and exc.reason == "Conflict" and msg in exc.body:
        return K8S_ALREADY_EXIST_REASON
    return ""

def launch_kubernetes_kernel(kernel_id, port_range, response_addr, public_key,
                              spark_context_init_mode, pod_template_file,
                              spark_opts_out, kernel_class_name):
    if os.getenv("KUBERNETES_SERVICE_HOST"):
        config.load_incluster_config()
    else:
        config.load_kube_config()

    keywords = {}
    if port_range: os.environ["PORT_RANGE"] = port_range
    if public_key: os.environ["PUBLIC_KEY"] = public_key
    if response_addr: os.environ["RESPONSE_ADDRESS"] = response_addr
    if kernel_id: os.environ["KERNEL_ID"] = kernel_id
    if spark_context_init_mode: os.environ["KERNEL_SPARK_CONTEXT_INIT_MODE"] = spark_context_init_mode
    if kernel_class_name: os.environ["KERNEL_CLASS_NAME"] = kernel_class_name

    os.environ["KERNEL_NAME"] = os.path.basename(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    )

    for name, value in os.environ.items():
        if name.startswith("KERNEL_"):
            keywords[name.lower()] = yaml.safe_load(value)

    k8s_yaml = generate_kernel_pod_yaml(keywords)
    pod_template = None
    pod_created = None
    kernel_namespace = keywords["kernel_namespace"]

    for k8s_obj in yaml.safe_load_all(k8s_yaml):
        if not k8s_obj.get("kind"):
            sys.exit(f"ERROR - Unknown object '{k8s_obj}'")
        if k8s_obj["kind"] == "Pod":
            pod_template = extend_pod_env(k8s_obj)
            if pod_template_file is None:
                try:
                    pod_created = client.CoreV1Api(client.ApiClient()).create_namespaced_pod(
                        body=k8s_obj, namespace=kernel_namespace
                    )
                except ApiException as exc:
                    if _parse_k8s_exception(exc) == K8S_ALREADY_EXIST_REASON:
                        pod_created = client.CoreV1Api(client.ApiClient()).list_namespaced_pod(
                            namespace=kernel_namespace,
                            label_selector=f"kernel_id={kernel_id}",
                            watch=False,
                        ).items[0]
                    else:
                        raise exc
        elif k8s_obj["kind"] == "Service":
            if pod_template_file is None and pod_created is not None:
                k8s_obj["metadata"]["ownerReferences"] = [{
                    "apiVersion": "v1", "kind": "pod",
                    "name": str(pod_created.metadata.name),
                    "uid": str(pod_created.metadata.uid),
                }]
                client.CoreV1Api(client.ApiClient()).create_namespaced_service(
                    body=k8s_obj, namespace=kernel_namespace
                )

    if pod_template_file:
        with open(pod_template_file, "w") as f:
            yaml.dump(pod_template, f)
        additional_spark_opts = (
            f"--conf spark.kubernetes.driver.podTemplateFile={pod_template_file} "
            f"--conf spark.kubernetes.executor.podTemplateFile={pod_template_file} "
        )
        if spark_opts_out:
            with open(spark_opts_out, "w+") as f:
                f.write(additional_spark_opts)
        else:
            print(additional_spark_opts)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--kernel-id", dest="kernel_id", nargs="?")
    parser.add_argument("--port-range", dest="port_range", nargs="?")
    parser.add_argument("--response-address", dest="response_address", nargs="?")
    parser.add_argument("--public-key", dest="public_key", nargs="?")
    parser.add_argument("--spark-context-initialization-mode", dest="spark_context_init_mode", nargs="?")
    parser.add_argument("--pod-template", dest="pod_template_file", nargs="?")
    parser.add_argument("--spark-opts-out", dest="spark_opts_out", nargs="?")
    parser.add_argument("--kernel-class-name", dest="kernel_class_name", nargs="?")
    parser.add_argument("--RemoteProcessProxy.kernel-id", dest="rpp_kernel_id", nargs="?")
    parser.add_argument("--RemoteProcessProxy.port-range", dest="rpp_port_range", nargs="?")
    parser.add_argument("--RemoteProcessProxy.response-address", dest="rpp_response_address", nargs="?")
    parser.add_argument("--RemoteProcessProxy.public-key", dest="rpp_public_key", nargs="?")
    parser.add_argument("--RemoteProcessProxy.spark-context-initialization-mode",
                        dest="rpp_spark_context_init_mode", nargs="?", default="none")

    args = vars(parser.parse_args())
    launch_kubernetes_kernel(
        args["kernel_id"] or args["rpp_kernel_id"],
        args["port_range"] or args["rpp_port_range"],
        args["response_address"] or args["rpp_response_address"],
        args["public_key"] or args["rpp_public_key"],
        args["spark_context_init_mode"] or args["rpp_spark_context_init_mode"],
        args["pod_template_file"],
        args["spark_opts_out"],
        args["kernel_class_name"],
    )
