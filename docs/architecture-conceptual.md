# Kien Truc Tong The Theo Ban Chat

Tai lieu nay dung de trinh bay voi thay theo muc "em hieu he thong dang giai quyet van de gi", khong di vao ten tool truoc. Tool/framework nam o tai lieu pipeline rieng.

## 1. Developer Dua Code Vao Repository

Developer khong dua thang code len production. Developer tao branch rieng cho tung feature hoac bug fix, sau do tao pull request vao nhanh tich hop.

Repository la nguon su that cua he thong: no luu source code, cau hinh, ha tang, lich su thay doi va la noi kich hoat cac buoc kiem soat.

Y nghia:

- Tach code dang lam voi code on dinh.
- Ghi lai ai sua, sua gi, vi sao sua.
- Tao noi de review truoc khi merge.
- Tao diem kich hoat cho kiem tra tu dong.

Ghi chu ve tu "pool": trong boi canh nay cach goi dung thuong la `pull request`, `integration branch`, hoac `merge queue`. Neu y la noi gom nhieu feature de kiem tra chung thi do la nhanh tich hop, vi du `dev`.

## 2. Quet So Bo Khi Co Pull Request

Khi pull request duoc tao, he thong can quet so bo code truoc khi cho code vao nhanh tich hop. Muc tieu la bat loi som, khong doi den luc deploy moi phat hien.

Vi du quan trong nhat la secret scanning. Neu developer hardcode token, password, private key hoac access key vao code, secret do co the nam trong lich su Git ke ca sau khi da xoa. Vi vay secret phai bi chan ngay tai pull request.

Ngoai secret, buoc so bo co the kiem tra:

- Mau code co dau hieu gay bug hoac lo hong.
- Thu vien phu thuoc co rui ro.
- Container build file, deployment manifest, infrastructure code co cau hinh nguy hiem.
- Format va loi cau hinh co ban.

Y nghia:

- Feedback nhanh cho developer.
- Giam chi phi sua loi.
- Ngan loi ro rang di vao nhanh tich hop.
- Bao ve repository khoi secret va cau hinh nhay cam.

## 3. Nhanh Tich Hop Gom Nhieu Feature

Sau khi pull request pass kiem tra so bo va duoc review, code duoc merge vao nhanh tich hop, vi du `dev`.

Nhanh tich hop khong phai production. No la noi gom nhieu feature lai de kiem tra xem chung co hoat dong dung khi di cung nhau hay khong.

Ly do can nhanh tich hop:

- Tung feature rieng co the dung, nhung khi ghep voi feature khac co the xung dot.
- Cau hinh ung dung, ha tang va deployment can duoc kiem tra nhu mot bo.
- Can co mot noi tao release candidate truoc khi vao nhanh release.

Y nghia:

- Kiem tra chat luong o muc tong the.
- Phat hien loi do nhieu thay doi ket hop.
- Chuan bi mot ban release candidate sach hon.

## 4. Ranh Gioi Release

Khi nhanh tich hop da on dinh, he thong tao pull request tu `dev` sang `main`. Day la ranh gioi release.

O buoc nay cau hoi khong con la "feature nay co dung khong", ma la "toan bo phien ban nay co du dieu kien de release khong".

Can kiem tra nghiem hon:

- Code co lo hong nghiem trong khong.
- Cau hinh ha tang co mo quyen qua rong khong.
- Manifest Kubernetes co vi pham policy khong.
- Dependency co rui ro cao khong.
- Ban release co the build thanh artifact nhat quan khong.

Y nghia:

- Tach moi truong tich hop voi moi truong release.
- Chi cho ban da qua gate vao `main`.
- Tao diem kiem soat truoc khi sinh artifact that.

## 5. Build Artifact Bat Bien

Sau khi code vao `main`, pipeline build source code thanh container image. Tu luc nay he thong deploy artifact, khong deploy source code truc tiep.

Artifact can bat bien. Nghia la cung mot image digest thi noi dung ben trong khong thay doi. Neu chi dung tag nhu `latest`, ta khong biet production dang chay dung ban nao. Neu dung digest, ta truy vet duoc production dang chay image nao va image do sinh tu commit nao.

Y nghia:

- Bien source code thanh don vi trien khai.
- Dam bao staging va production dung cung artifact da kiem tra.
- Truy vet duoc tu production ve commit nguon.

## 6. Kiem Soat Chuoi Cung Ung Phan Mem

Sau khi build image, he thong can chung minh image do dung la image do pipeline tao ra va chua bi thay the.

Can tra loi:

- Image nay sinh tu commit nao?
- Image nay gom nhung package/dependency nao?
- Image nay co bi thay the tren registry khong?

Vi vay artifact can co danh sach thanh phan va chu ky. Danh sach thanh phan giup biet trong image co gi. Chu ky giup cluster xac minh image den tu pipeline hop le.

Y nghia:

- Chong thay the image.
- Truy vet khi co CVE moi.
- Tao bang chung bao mat chuoi cung ung.

## 7. Staging Truoc Production

Truoc khi vao production, image phai duoc deploy len staging. Staging la moi truong gan production, dung de kiem tra app khi da chay that voi service, config, secret, network va database.

Can kiem tra:

- Pod co san sang khong.
- Endpoint co tra ve thanh cong khong.
- App co ket noi duoc thanh phan phu thuoc khong.
- Runtime co loi khong.
- Quet dong co phat hien loi web co ban khong.

Y nghia:

- Bat loi chi xuat hien khi app chay that.
- Kiem tra duong di tu user den service.
- Giam rui ro truoc khi cap nhat production.

## 8. Promotion Bang GitOps

Sau khi staging pass, pipeline khong day thang len production. Pipeline tao mot thay doi ve desired state cua production trong Git, goi la promotion PR.

Production chi thay doi khi promotion PR duoc chap nhan. Cluster doc Git va tu dong dong bo trang thai production theo noi dung trong Git.

Y nghia:

- Git la nguon su that cua production.
- Moi thay doi production co review va lich su.
- De rollback vi co the quay lai desired state cu.
- Tach quyen build artifact voi quyen thay doi production.

## 9. Kiem Soat Runtime

Sau khi ung dung da chay, van can kiem soat runtime. Pipeline khong du de bao ve toan bo he thong, vi co the co nguoi apply tay, dung image sai, gan secret sai hoac workload co hanh vi bat thuong.

Cluster can co cac lop:

- Chi chap nhan image co nguon goc hop le.
- Khong de secret nam truc tiep trong manifest.
- Gioi han quyen cua workload.
- Kiem soat network giua service.
- Ghi log, metric va canh bao khi co bat thuong.

Y nghia:

- Bao ve he thong sau khi deploy.
- Chan cau hinh sai tai runtime.
- Tao bang chung van hanh khi co incident.

## 10. Multi-Cloud Va Disaster Recovery

He thong co AWS la site chinh va Azure la warm standby. Warm standby co nghia la moi truong du phong da ton tai va san sang nhan workload/traffic khi can, nhung traffic chinh van di vao AWS.

DR khong chi la co them mot cluster. DR can co network path, data replication, cach chuyen traffic va quy trinh khoi phuc.

Y nghia:

- Giam phu thuoc vao mot cloud.
- Co duong failover khi primary site loi.
- Chung minh kha nang recover thay vi chi deploy thanh cong.

## 11. Doan Noi 30 Giay

```text
Kien truc cua em di theo dong chay DevSecOps. Developer khong day thang code len production ma tao pull request vao repository. PR duoc quet so bo de chan secret, loi code va cau hinh nguy hiem. Sau khi qua review, feature vao nhanh tich hop `dev` de kiem tra nhieu thay doi chung voi nhau. Khi code vao `dev`, pipeline build container image bat bien, tao SBOM, ky image va scan CVE tren artifact. Image do duoc deploy len staging de test runtime va DAST. Neu staging pass, pipeline tao promotion PR tu tested `dev` commit vao `main`, kem production Helm values pin dung image digest da test. Production va Azure khong nhan lenh deploy truc tiep tu CI, ma duoc dong bo tu Git sau khi PR duoc review. Runtime tiep tuc co policy, secret management, monitoring va DR.
```
