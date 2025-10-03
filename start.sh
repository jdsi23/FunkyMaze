# Start Terraform install
echo "[+] Downloading Terraform 1.7.5..."
curl -O https://releases.hashicorp.com/terraform/1.7.5/terraform_1.7.5_linux_amd64.zip
unzip -o terraform_1.7.5_linux_amd64.zip

echo "[+] Moving Terraform binary to /usr/local/bin..."
sudo mv terraform /usr/local/bin/

# cd to terraform location
cd Infra

# Run Terraform
terraform init -input=false
terraform apply -auto-approve
cd ..

# Run grab_names.sh 
chmod +x grab_names.sh
./grab_names