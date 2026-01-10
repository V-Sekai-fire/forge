#!/usr/bin/env elixir

# Script to generate self-signed certificates for CockroachDB development
# Creates CA, node, and client certificates

defmodule CockroachCertGen do
  @certs_dir "cockroach-certs"

  def run do
    # Create certificates directory
    File.mkdir_p!(@certs_dir)

    IO.puts("Generating CockroachDB certificates...")

    # Generate CA
    IO.puts("1. Generating CA certificate...")
    generate_ca()

    # Generate node certificate
    IO.puts("2. Generating node certificate...")
    generate_node_cert()

    # Generate client certificate
    IO.puts("3. Generating client certificate...")
    generate_client_cert()

    IO.puts("Certificates generated successfully!")
    IO.puts("Certificate files created in: #{@certs_dir}")
    IO.puts("")
    IO.puts("To start CockroachDB with TLS:")
    IO.puts("cockroach start-single-node --certs-dir=#{@certs_dir} --listen-addr=localhost:26257 --http-addr=localhost:8080")
  end

  defp generate_ca do
    # Generate CA private key
    ca_key = X509.PrivateKey.new_rsa(2048)

    # Generate CA certificate
    ca_cert = X509.Certificate.self_signed(
      ca_key,
      "/C=US/ST=CA/L=San Francisco/O=Cockroach Labs/OU=Test/CN=Cockroach CA",
      template: :root_ca
    )

    # Save CA certificate and key
    File.write!("#{@certs_dir}/ca.crt", X509.Certificate.to_pem(ca_cert))
    File.write!("#{@certs_dir}/ca.key", X509.PrivateKey.to_pem(ca_key))
  end

  defp generate_node_cert do
    # Load CA
    ca_cert = File.read!("#{@certs_dir}/ca.crt") |> X509.Certificate.from_pem!()
    ca_key = File.read!("#{@certs_dir}/ca.key") |> X509.PrivateKey.from_pem!()

    # Generate node private key
    node_key = X509.PrivateKey.new_rsa(2048)

    # Generate node certificate
    node_cert = X509.Certificate.new(
      X509.PublicKey.derive(node_key),
      "/C=US/ST=CA/L=San Francisco/O=Cockroach Labs/OU=Test/CN=node",
      ca_cert,
      ca_key,
      extensions: [
        subject_alt_name: X509.Certificate.Extension.subject_alt_name([
          {:dNSName, "localhost"},
          {:dNSName, "node"}
        ])
      ]
    )

    # Save node certificate and key
    File.write!("#{@certs_dir}/node.crt", X509.Certificate.to_pem(node_cert))
    File.write!("#{@certs_dir}/node.key", X509.PrivateKey.to_pem(node_key))
  end

  defp generate_client_cert do
    # Load CA
    ca_cert = File.read!("#{@certs_dir}/ca.crt") |> X509.Certificate.from_pem!()
    ca_key = File.read!("#{@certs_dir}/ca.key") |> X509.PrivateKey.from_pem!()

    # Generate client private key
    client_key = X509.PrivateKey.new_rsa(2048)

    # Generate client certificate
    client_cert = X509.Certificate.new(
      X509.PublicKey.derive(client_key),
      "/C=US/ST=CA/L=San Francisco/O=Cockroach Labs/OU=Test/CN=root",
      ca_cert,
      ca_key,
      extensions: [
        key_usage: X509.Certificate.Extension.key_usage([:digitalSignature, :keyEncipherment]),
        ext_key_usage: X509.Certificate.Extension.ext_key_usage([:clientAuth])
      ]
    )

    # Save client certificate and key
    File.write!("#{@certs_dir}/client.root.crt", X509.Certificate.to_pem(client_cert))
    File.write!("#{@certs_dir}/client.root.key", X509.PrivateKey.to_pem(client_key))
  end
end

# Run the certificate generation
CockroachCertGen.run()
