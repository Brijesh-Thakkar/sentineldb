from setuptools import setup, find_packages

setup(
    name="sentineldb-client",
    version="0.1.0",
    description="Python client for SentinelDB — the negotiating key-value store",
    author="Brijesh Thakkar",
    url="https://github.com/Brijesh-Thakkar/sentineldb",
    packages=find_packages(),
    install_requires=["requests>=2.28.0"],
    python_requires=">=3.8",
    classifiers=[
        "Development Status :: 3 - Alpha",
        "Intended Audience :: Developers",
        "Topic :: Database",
    ],
)
