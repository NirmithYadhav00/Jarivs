base = r"D:\lucky-AI\frontend\assets\avatar"

three = open(base + "/three.min.js", "r", encoding="utf-8").read()
gltf = open(base + "/GLTFLoader.js", "r", encoding="utf-8").read()
vrm = open(base + "/three-vrm.js", "r", encoding="utf-8").read()
html = open(base + "/lucky_viewer.html", "r", encoding="utf-8").read()

html = html.replace(
    '<script src="three.min.js"></script>', "<script>\n" + three + "\n</script>"
)
html = html.replace(
    '<script src="GLTFLoader.js"></script>', "<script>\n" + gltf + "\n</script>"
)
html = html.replace(
    '<script src="three-vrm.js"></script>', "<script>\n" + vrm + "\n</script>"
)

open(base + "/lucky_viewer.html", "w", encoding="utf-8").write(html)
print("Done! Size:", len(html), "chars")

# Verify UMD assignment survived
import re

matches = re.findall(r"THREE_VRM\s*=", html)
print("THREE_VRM= occurrences:", len(matches))
