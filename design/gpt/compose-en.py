import qrcode,numpy as np,cv2
from PIL import Image,ImageDraw
S=3
im=Image.open('original.png').convert('RGB'); a=np.array(im)
# 1) remove wrong text (title 'המיד' and subtitle) by inpainting on the 1x image
cream=np.array([251,246,235])
mask=np.zeros(a.shape[:2],np.uint8)
def add(x0,y0,x1,y1,th):
    reg=a[y0:y1,x0:x1].astype(int); d=np.abs(reg-cream).max(axis=2)
    mask[y0:y1,x0:x1][d>th]=255
add(430,314,680,392,28); add(285,396,820,448,40); add(290,1125,812,1185,40)
mask=cv2.dilate(mask,np.ones((9,9),np.uint8))
bgr=cv2.cvtColor(a,cv2.COLOR_RGB2BGR); out=cv2.inpaint(bgr,mask,7,cv2.INPAINT_TELEA)
base=Image.fromarray(cv2.cvtColor(out,cv2.COLOR_BGR2RGB)).resize((im.width*S,im.height*S),Image.LANCZOS)
# 2) repaint the QR card interior and draw a correct QR (direct App Store link)
URL='https://apps.apple.com/app/id6807186847'
q=qrcode.QRCode(error_correction=qrcode.constants.ERROR_CORRECT_M,border=0,box_size=1);q.add_data(URL);q.make(fit=True)
M=q.get_matrix();N=len(M)
d=ImageDraw.Draw(base)
x0,y0,x1,y1=247*S,509*S,855*S,1099*S
d.rectangle([x0,y0,x1,y1],fill=(254,251,244))
mod=min((x1-x0),(y1-y0))//(N+8); size=mod*N
ox=(x0+x1)//2-size//2; oy=(y0+y1)//2-size//2
navy=(13,27,61)
for r in range(N):
    for c in range(N):
        if M[r][c]: d.rectangle([ox+c*mod,oy+r*mod,ox+(c+1)*mod-1,oy+(r+1)*mod-1],fill=navy)
# 3) new correct texts
t=Image.open('texts-en.png').convert('RGBA')
tt=t.crop((0,0,1800,360)); ss=t.crop((0,380,1800,600)); cc=t.crop((0,600,1800,860))
def place(layer,cx,cy):
    bb=layer.getbbox(); layer=layer.crop(bb)
    base.paste(layer,(int(cx*S-layer.width/2),int(cy*S-layer.height/2)),layer)
place(tt,550.5,349); place(ss,550.5,421); place(cc,550.5,1157)
base.convert('RGB').save('tamid-qr-appstore-en.png',dpi=(400,400)); print(base.size,N,mod)
