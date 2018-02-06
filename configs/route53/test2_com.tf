module "route53_public_zone2" { 
  source = "../../modules/route53_public_zone"
  zone_name = "test2.com"
}
