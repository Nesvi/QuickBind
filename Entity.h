#ifndef _Entity
#define _Entity
#include <SFML/Graphics.hpp>

class Entity{

 private:
  sf::Sprite sprite;
  static sf::Texture texture;
 public:
  Entity();

  static void InitializeStatic();

  sf::Sprite Draw();
  void Update();//LUACALL
  

  void setPosition(const float& arga, const float& argb);//BIND
  float getX();//BIND
  float getY();
  void voidfunc();//BIND
  char* getText();//BIND
};


#endif
