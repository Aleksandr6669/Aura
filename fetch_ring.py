import urllib.request

url = "https://raw.githubusercontent.com/Lupin3000/ColmiSmartRing/main/ColmiRingAccelerometer.py"
response = urllib.request.urlopen(url)
content = response.read().decode('utf-8')

with open("accel_original.py", "w") as f:
    f.write(content)

print("Saved accel successfully!")
